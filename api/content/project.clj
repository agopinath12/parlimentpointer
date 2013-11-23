(defproject content "0.1.0-SNAPSHOT"
  :description "FIXME: write description"
  :url "http://example.com/FIXME"
  :dependencies [[org.clojure/clojure "1.5.1"]
                 [compojure "1.1.6"]
                 [com.novemberain/monger "1.5.0"]
                 [ring/ring-jetty-adapter "1.2.1"]
                 [ring-json-params "0.1.3"]
                 [clj-json "0.5.3"]]
  :plugins [[lein-ring "0.8.8"]]
  :ring {:handler content.handler/app}
  :profiles
  {:dev {:dependencies [[javax.servlet/servlet-api "2.5"]
                        [ring-mock "0.1.5"]]}})
