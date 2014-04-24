#used for managing from irb

require 'sinatra'
require "sinatra/json"
require 'mongo'
require 'pstore'
require 'digest/md5'

include Mongo


client = MongoClient.new # defaults to localhost:27017
db     = client['example-db']
$rates = db['rate-coll']
$users = db['user-coll']
$rating = db['rating-coll']
$cmps = db['compares-coll']
$proposals = db['proposal-coll']
$forms = db['form-coll']
$addvoters = db['add-ip-coll']
$subvoters = db['sub-ip-coll']

load './helpers.rb'