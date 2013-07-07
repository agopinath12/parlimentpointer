use warnings;
use strict;
use XML::Simple;
use Data::Dumper;
use DBI;
my $dbfile = 'new_db.sqlite';
unlink $dbfile || die "Can't remove dbfile\n";
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
$dbh->{autocommit} = 1;

#we'll start by parsing out all the people data we have
my $people_path = 'data\people.xml';
open my $PFH, '<', $people_path;
# now dump it in a db
$dbh->do("CREATE TABLE PEOPLE (id INTEGER PRIMARY KEY AUTOINCREMENT, source_key INTEGER, latest_name TEXT)");

my ($peopleA, $mpsH, $lordsH, $ministersH) = parse_people($PFH);

my $insert_person_query = $dbh->prepare('INSERT INTO PEOPLE(source_key, latest_name) VALUES(?,?)');

$dbh->begin_work;

foreach my $person (@$peopleA){
	
    $insert_person_query->execute($person->[0], $person->[1]);
}
$dbh->commit;
close $PFH;

#now we're interested in MPships
$dbh->do("CREATE TABLE MPSHIPS (id INTEGER PRIMARY KEY AUTOINCREMENT, source_key INTEGER, " .
                                  "person_key REFERENCES PEOPLE(source_key) ON DELETE CASCADE, " .
                                  "house TEXT, title TEXT, firstname TEXT, lastname TEXT, " .
                                  "constituency TEXT, party TEXT, fromdate TEXT, todate TEXT, " .
                                  "fromwhy TEXT, towhy TEXT)");
                                  
my $insert_mpship_query = $dbh->prepare('INSERT INTO MPSHIPS(source_key, person_key, house, title, firstname, '.
                                        'lastname, constituency, party, fromdate, todate, '.
                                        'fromwhy, towhy) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)');
                                        
foreach my $member_path ('data\all-members.xml', 'data\all-members-2010.xml'){;
  open my $MFH, '<', $member_path;
  # now dump it in a db


  my $ref = XMLin($MFH);

  $dbh->begin_work;
  my $mpshipH = $ref->{member};
  
  foreach my $mpshipid (keys %$mpshipH){
    my $mpship = $mpshipH->{$mpshipid};
    my ($domain, $class, $id) = split '/', $mpshipid;
    my $person_id = $mpsH->{$id} || die "bugger, couldn't find person to link office $id to :(";
    $insert_mpship_query->execute($id, $person_id, $mpship->{house}, $mpship->{title}, $mpship->{firstname},
                                  $mpship->{lastname}, $mpship->{constituency}, $mpship->{party},
                                  $mpship->{fromdate}, $mpship->{todate}, $mpship->{fromwhy}, $mpship->{towhy});
  }
  $dbh->commit;
  close $MFH;
}

#Lordships
open my $LFH, '<', 'data\peers-ucl.xml' or die "couldnt get at lords file";
my $ref = XMLin($LFH);
$dbh->do("CREATE TABLE LORDSHIPS (id INTEGER PRIMARY KEY AUTOINCREMENT, source_key INTEGER, " .
                                  "person_key REFERENCES PEOPLE(source_key) ON DELETE CASCADE, " .
                                  "house TEXT, forenames TEXT, forenames_full TEXT, title TEXT, " .
                                  "lordname TEXT, lordofname TEXT, lordofname_full TEXT, county TEXT, " .
                                  "peeragetype TEXT, affiliation TEXT, fromdate TEXT, todate TEXT, ex_MP TEXT)");

my $insert_lordship_query = $dbh->prepare("insert into LORDSHIPS (source_key, person_key, house, forenames, forenames_full, title, " .
                                  "lordname, lordofname, lordofname_full, county, peeragetype, affiliation, ".
                                  "fromdate, todate, ex_MP) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");

                                  
$dbh->begin_work;
my $lordshipH = $ref->{lord};
foreach my $lordshipid (keys %$lordshipH){
  my $lordship = $lordshipH->{$lordshipid};
  my ($domain, $class, $id) = split '/', $lordshipid;
  my $person_id = $lordsH->{$id} || die "bugger, couldn't find person to link office $id to :(";
  $insert_lordship_query->execute($id, $person_id, $lordship->{house}, $lordship->{forenames}, $lordship->{forenames_full},
                                   $lordship->{title}, $lordship->{lordname}, $lordship->{lordofname},
                                   $lordship->{lordofname_full}, $lordship->{county}, $lordship->{peeragetype}, $lordship->{affiliation},
                                   $lordship->{fromdate}, $lordship->{todate}, $lordship->{ex_MP});
}
$dbh->commit;
close $LFH;

sub parse_people{
  my $FH = shift;
  my $ref = XMLin($FH);
  my @people;
  my %mplinks;
  my %lordlinks;
  my %offlinks;
  
  my $peopleH = $ref->{person};
  foreach my $person_key (keys %{$peopleH}){
    my ($p_domain, $p_class, $p_id) = split '/', $person_key;
    
    my $name = $peopleH->{$person_key}{latestname};
    push @people, [$p_id, $name];
    my $officesH = $peopleH->{$person_key}{office};
    print Dumper($officesH) if $p_id == 14101;
    foreach my $office_key (keys %$officesH){
        if ($office_key eq 'id'){
            $office_key = $officesH->{$office_key};
        }
        my ($o_domain, $o_class, $o_id) = split '/', $office_key;
        if (defined $o_id){
          print "Hello" if $o_id == 101127;
          if ($o_class eq 'member'){
            $mplinks{$o_id} = $p_id;  
          }
          elsif ($o_class eq 'lord'){
            $lordlinks{$o_id} = $p_id;
          }
          elsif ($o_class eq 'moffice'){
            $offlinks{$o_id} = $p_id; 
          }
          else{
            die "Unknown link type $o_class" unless ($o_class eq 'royal');  #TODO: stick royals in a table too
          }
        }
        else{
          die "Invalid office key '$office_key'" unless ($office_key eq 'current');  #we can use term dates to figure out who's current
        }
    }
  }
  return (\@people, \%mplinks, \%lordlinks, \%offlinks);
}