


module User
	module_function
	
	def get_by_name name
		$users.find_one(name: name)
	end


	def set_photos uid, photos
		$users.update( {_id: uid} , {:$set => {photos: photos}})
	end


	def add name,photos,sex
		$users.update(
			{:name => name },
			{ :$addToSet => 
				{:photos => 
					{ :$each => photos}},
					:$set => {:sex => sex, :rnd => rand }},
					{:upsert => true})
	end


	def set_photos_by_name name, photos
		set_photos(get_by_name(name)['_id'], photos)
	end


	def add_photos_by_name name,photos
		$users.update({:name => name},
			{:$addToSet => 
				{:photos => 
					{ :$each => photos}}})
	end


	def delete_photo_by_name name, photo
		$users.update({:name => name},
			{:$pull => {:photos => photo }})
	end	


	def clear_photos uid
		set_photos uid, []
	end


	def clear_photos_by_name name
		uid = get_by_name(name)['_id']
		clear_photos uid
	end


	def set_form uid,form,sure
		$forms.update(
			{:user_id => uid},
			{:$inc => {form.to_s => sure } },
			{:upsert => true})
	end


	def set_form_by_name name, form, sure
		u = get_by_name name
		uid = u['_id']
		set_form uid,form,sure
	end


	def delete_form_by_name name, form
		begin
			u = get_by_name name
			uid = u['_id']

			$forms.update(
				{:user_id => uid},
				{:$set => {form.to_s => 0 } },
				{:upsert => true})
		rescue Exception => e
			e
		end
	end


	def add_rating uid,rid,count
		$rating.update({rate_id: rid, user_id: uid},
			{:$inc => {:rate => count}})
	end


	def set_multiply_form_by_names user_names, form,sure

		user_names.map{|e|
			begin 
				set_form_by_name(e,form,sure)
			rescue Exception => e
				e
			end
		}
	end


	def get_random sex
		$users.find({:sex => sex}).to_a.sample
	end
	

	def get_other_random user1,sex
		$users.find(
			{ :sex => sex,
				:_id =>
				{ :$ne => user1['_id']}}).to_a.sample
	end	


	def get_form id

		forms = $forms.find_one(user_id: id)

		if forms.nil?
			nil
		else
			form_map ={}
			(1..11).each{|e| 
				if forms[e.to_s]
					form_map[e]=forms[e.to_s] 
				end
			}
			(form_map.max_by {|k,v| v})[0]
		end
	end	


	def all
		$users.find.to_a
	end

	def delete_rates_by_name name, rate_ids=nil
		uid = get_user_by_name(name)['_id']
		if rate_ids.nil?
			$rating.remove(user_id: uid)
		else
			rate_ids.map{|rid| $rating.remove(user_id: uid, rate_id: rid) }
		end
		
	end


end


def add_rate ask,top_text,sex
	$rates.update(
		{:top_text => top_text},
		{:$set => { :sex => sex , :ask => ask, :rnd => rand }},
		{:upsert => true})
end


def elo_rate r_a, r_b, win
	s = win ? 1 : 0

	e_a = 1.0 / ( 1 + 10**(  (r_b-r_a) / 400.0  ))
	
	(r_a + 32 * (s - e_a)).to_i
end


def get_random_rate
	$rates.find.to_a.sample
end


def add_voter_ip ip, uid,count, type
	voted_user_name = $users.find_one(:_id => uid)['name']
	if type==:add
		$addvoters.update({:ip => ip},
			{:$inc => 
				{voted_user_name => count}},
				{:upsert => true})
	else
		$subvoters.update({:ip => ip},
			{:$inc => 
				{voted_user_name => count}},
				{:upsert => true})


	end
end

def error_guard
	begin
		yield
	rescue Exception => e
		$stderr.puts e.message
		$stderr.puts e.backtrace
		halt 400, "WTF?!"
	end
end


def all_addvoters
	$addvoters.find.to_a
end


def all_subvoters
	$subvoters.find.to_a
end