require 'sinatra'
require "sinatra/json"
require 'mongo'
require 'pstore'
require 'digest/md5'
require './helpers'
include Mongo


configure do
	# connecting to the database

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

	$admin_login = 'atmine'
	$admin_password = 'atmine'

end

helpers do
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Admins"'
    halt 401, "Не знаешь пароль - не лезь\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [$admin_login, $admin_password]
  end
end

post '/add' do 
	error_guard do
		protected!

		if params[:name].nil? ||  params[:photos].nil? ||  params[:sex].nil?
			$stderr.puts "Bad user"
			halt 400,"WTF?!"
		end

		name = params[:name]
		photos = params[:photos]
		sex = params[:sex]

		User::add name,photos,sex
		""
	end
end

post "/newrate" do
	error_guard do
		protected!

		if params[:ask].nil? ||  params[:top_text].nil? ||  params[:sex].nil?
			$stderr.puts "Bad rate"
			halt 400,"WTF?!"
		end

		ask = params[:ask]
		sex = params[:sex]
		top_text = params[:top_text]
		add_rate ask,top_text,sex

		""
	end
end

post "/getpair" do
	error_guard do
		rate = get_random_rate
		
		sex = rate['sex']

		user1 = User::get_random sex
		user2 = User::get_other_random user1,sex

		if user1.nil? || user2.nil?
			$stderr.puts "No users"
			halt 500, "We haven't much users\n" 
		end
		
		user1_p = user1['photos'].sample
		user2_p = user2['photos'].sample

		user1_form = User::get_form(user1['_id'])
		user2_form = User::get_form(user2['_id'])

		time = Time.now.to_i
		hash = Digest::MD5.hexdigest("#{time}#{user1['name']}#{user1_p}#{user2['name']}#{user2_p}#{rate['ask']}")
		
		$cmps.insert( {:hash => hash, :left => user1['_id'], :right => user2['_id'] , :rid => rate['_id'] ,:ts => time} )

		json( {:hash => hash, 
				:left => {:photo => user1_p, :name =>  user1['name'], :form => user1_form}, 
				:right => {:photo => user2_p, :name =>  user2['name'], :form => user2_form},
				:ask => rate['ask'] } )
	end
end

post "/clear" do 
	error_guard do
		protected!
		$cmps.remove({ :ts => { :$lt => Time.now.to_i - 10*60 }})
		GC.start
	end
end

post "/votefor" do

	error_guard do
		cmp = $cmps.find_and_modify(
				{:query => {:hash => params[:hash]},
				 :remove => true } )

		if cmp.nil? || cmp['ts'] < Time.now.to_i-10*60
			$stderr.puts "invalid cmp"
			halt 400, "Fuck off\n" 
		end

		case params[:side]
		when "left"
			winner = cmp["left"]
			loser = cmp["right"]
		when "right"
			winner = cmp["right"]
			loser = cmp["left"]
		else
			$stderr.puts "invalid side"
			halt 400, "Fuck off\n"
		end

		winner_rate = $rating.find_and_modify(
			{:query => 
				{:rate_id => cmp['rid'],
				 :user_id => winner },
			 :update => 
				{:$setOnInsert => {:rate => 1000 }},
			 :new => true,
			 :upsert => true})
		
		loser_rate = $rating.find_and_modify(
			{:query => 
				{:rate_id => cmp['rid'],
				 :user_id => loser },
			 :update => 
				{:$setOnInsert => {:rate => 1000 }},
			 :new => true,
			 :upsert => true})
		
		winner_rate = winner_rate['rate']
		loser_rate = loser_rate['rate']

		new_winner_rate = elo_rate winner_rate , loser_rate , true
		new_loser_rate = elo_rate loser_rate , winner_rate , false

		$rating.update(
				{:user_id => winner, :rate_id => cmp['rid'] },
				{:$set => { :rate => new_winner_rate }})

		$rating.update(
				{:user_id => loser, :rate_id => cmp['rid'] },
				{:$set => { :rate => new_loser_rate }})
		""
	end
end

post "/tops" do
	error_guard do
		json $rates.find.to_a.map { |rate| { :text => rate['top_text'], :id => rate['_id'].to_s} }
	end
end

post "/gettop" do
	error_guard do
		if params[:id]=="all"
			json({:top_text => "Все пользователи",
				  :top_array=> 	User::all.map{|user| 
				  			{:name => user['name'],
				  			 :photo => {:src => user['photos'].sample},
				  			 :rate => User::get_form(user['_id']).to_s + " класс",
				  			 :form => User::get_form(user['_id'])}
				  		}
				  })
		else

			top_text = $rates.find_one({ :_id => BSON::ObjectId(params[:id]) })['top_text']
			top_array = $rating
							.find({ :rate_id => BSON::ObjectId(params[:id]) })
							.to_a
							.map { |rate| 
								begin
									user = $users.find_one( { :_id => rate['user_id'] })
									{:name => user['name'], 
									 :id => user['_id'].to_s,
									 :photo => {:src => user['photos'].sample},
									 :rate => rate['rate'],
									 :form => User::get_form(rate['user_id']) }
								rescue
									nil
								end
							}
							.compact #del nils
			json({:top_text => top_text, :top_array =>  top_array})
		end
	end
end

post "/newreq" do
	error_guard do
		$proposals.insert({:req_text => params[:req], :ip => request.ip})
		""
	end
end

post "/voteform" do
	error_guard do
		hash = params[:hash]
		side = params[:side]
		form = params[:form].to_i

		if !form.between?(1,11)
			$stderr.puts "Bad form"
			halt 400, "WTF?!"
		end

		cmp = $cmps.find_one(hash: hash)
		user_id = cmp[side]
		User::set_form user_id,form,1
		""
	end
end

post "/addrate" do
	error_guard do
		uid = BSON::ObjectId(params[:uid])
		rid = BSON::ObjectId(params[:rid])
		count = params[:count].to_i || 0

		add_voter_ip request.ip, uid,count, :add

		User::add_rating uid,rid,count
		""
	end
end

post "/subrate" do
	error_guard do
		uid = BSON::ObjectId(params[:uid])
		rid = BSON::ObjectId(params[:rid])
		count = params[:count].to_i || 0

		add_voter_ip request.ip, uid,count, :sub

		User::add_rating uid,rid,-count
		""
	end
end

get "/log" do
	error_guard do
		protected!
		`cat nohup.out | tail -n 100`
	end
end

get "/" do
	error_guard do
    	send_file "index.html" 
    end
end

get "/admin" do
	error_guard do
		protected!
		send_file "admin.html" 
	end
end