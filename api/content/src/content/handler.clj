(ns content.handler
  (:use compojure.core)
  (:use ring.middleware.json-params)
  (:require [compojure.handler :as handler]
            [compojure.route :as route]
            [clj-json.core :as json]
            [content.DBAccess :as db]))

(defn json-response
  "returns json response"
  [data & [status]]
  {:status (or status 200)
   :headers {"Content-Type" "application/json"}
   :body (json/generate-string data)
   }
  )

(defroutes app-routes
  (GET "/" [] (json-response {"hello" "world"}))
  (GET "/elems/:id" [id] (db/get_data id))
  (GET "/elems/:attr/:value" [attr value] (db/get_data (keyword attr) value))
  )

(def app
  (-> app-routes wrap-json-params))