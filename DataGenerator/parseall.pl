use warnings;
use strict;
use XML::Simple;
use Data::Dumper;
use MongoDB;
use MongoDB::OID;

my $client = new MongoDB::MongoClient();
my $db = $client->get_database('newdb');#creates a new db called "newdb" if required
$db->drop(); #clear any old junk before we start

#we'll start by parsing out all the people data we have
my $people_path = 'data\people.xml';
open my $PFH, '<', $people_path;
# now dump it in a db

my ($peopleA, $mpsH, $lordsH, $ministersH) = parse_people($PFH);

my $peopleC = $db->get_collection('people');

foreach my $person (@$peopleA){
    my $docH = {
                   source_id   => $person->[0],
                   latest_name => $person->[1]
               };
    $peopleC->insert($docH);               
}

close $PFH;


#now we're interested in MPships
foreach my $member_path ('data\all-members.xml', 'data\all-members-2010.xml'){;
  open my $MFH, '<', $member_path;
  # now dump it in a db
  my $ref = XMLin($MFH);

  my $mpshipHH = $ref->{member};
  my $mpshipsC = $db->get_collection('mpships');
  foreach my $mpshipid (keys %$mpshipHH){
    my $mpshipH = $mpshipHH->{$mpshipid};
    my ($domain, $class, $id) = split '/', $mpshipid;
    my $person_id = $mpsH->{$id} || warn "bugger, couldn't find person to link office $id to :(" ;
    next unless $person_id;#this entry corresponds to an unknown person
    $mpshipH->{'source_key'} = $id;
    $mpshipH->{'person_key'} = $person_id;
    
    
    $mpshipsC->insert($mpshipH);
  }
  close $MFH;
}

#Lordships
open my $LFH, '<', 'data\peers-ucl.xml' or die "couldnt get at lords file";
my $ref = XMLin($LFH);
                                  
my $lordshipHH = $ref->{lord};
my $lordshipsC = $db->get_collection('lordships');
foreach my $lordshipid (keys %$lordshipHH){
  my $lordshipH = $lordshipHH->{$lordshipid};
  my ($domain, $class, $id) = split '/', $lordshipid;
  my $person_id = $lordsH->{$id} || warn "bugger, couldn't find person to link office $id to :(";
  next unless $person_id;
  $lordshipH->{'source_key'} = $id;
  $lordshipH->{'person_key'} = $person_id;
  $lordshipsC->insert($lordshipH);
}
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