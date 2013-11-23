(ns content.DBAccess
  (:require [monger.core :as mg])
  (:require [monger.collection :as mc]))


;(mg/connect!)
;(mg/set-db! (mg/get-db "mpdb"))
;(mc/insert "document" { :first_name "John" :last_name "Lennon" })
;(println (mc/find-maps "document" {:first_name "John"}))

(defn connect_db []
  (mg/connect!)
  (mg/set-db! (mg/get-db "mpdb"))
  )

(defn get_data
  "gets data from mongo"
  ([id]
    (connect_db)
    (mc/find-by-id "document" id))

  ([key value]
    (connect_db)
    (mc/find-maps "document" {key value}))
  )