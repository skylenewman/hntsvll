require 'json'
require 'date'
require 'securerandom'

Pakyow::App.routes(:api) do
  include SharedRoutes

  expand :restful, :api, '/api' do
    collection do

      expand :restful, :v1, '/v1' do
        collection do

          expand :restful, :bhm, '/bhm' do
            collection do
              get 'cwn_flyer' do
                # "approved":true,
                # "cwn":88,
                # "timestamp":"2017-01-09T20:27:22.161Z",
                # "group":"Designer's Corner",
                # "title":"CoWorking Night Tshirt Competition",
                # "description":"Come in to get some last minute ideas for your entry to the CoWorking Night Tshirt competition! ",
                # "date":"2017-01-11T06:00:00.000Z",
                # "time_req_form":"8:00 PM",
                # "time_req":"1899-12-31T01:48:52.000Z",
                # "room_req":"Milky Way Row",
                # "start_time":"2017-01-12T02:00:00.000Z",
                # "end_time":"2017-01-12T03:00:00.000Z",
                # "isCancelled": "false"
                # "category":"Programming",
                # "icon":"terminal"
                if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))

                  #For now, we'll keep this only exposed for cwn
                  cwn = Group.where(Sequel.lit("name = 'CoWorking Night: Birmingham'")).first
                  if cwn.nil?
                   redirect '/errors/403'
                  end

                  #Now lets get all the events for this group. This means all of this group's events and its event's children
                  next_cwn_event = Event.where(Sequel.lit("approved = true AND start_datetime > ? AND group_id = ? AND archived = ?", DateTime.now.utc, cwn.id, false)).order(:start_datetime).first

                  #check is last cwn_event is still occurring. If it is, then use it
                  last_cwn_event = Event.where(Sequel.lit("approved = true AND start_datetime < ? AND group_id = ? AND archived = ?", DateTime.now.utc, cwn.id, false)).order(:start_datetime).last
                  unless last_cwn_event.nil?
                    if (((DateTime.now.utc.to_time - last_cwn_event.start_datetime) / 1.hours) < last_cwn_event.duration)
                      next_cwn_event = last_cwn_event
                    end
                  end

                  events = get_child_events_for_event(next_cwn_event)
                  response.write('[')
                  first_time = true
                  events.each { |event|
                   if first_time == true
                     first_time = false
                   else
                     response.write(',')
                   end
                   json =
                     {
                       "approved" => event.approved,
                       "cwn" => next_cwn_event.instance_number,
                       "timestamp" => event.created_at.utc,
                       "group" => Group.where(Sequel.lit("id = ?", event.group_id)).first.name,
                       "title" => event.name,
                       "description" => event.summary,
                       "date" => event.start_datetime.utc,
                       "time_req_form" => event.start_datetime.utc,
                       "time_req" => event.start_datetime.utc,
                       "room_req" => Venue.where(Sequel.lit("id = ?", event.venue_id)).first.name,
                       "start_time" => event.start_datetime.utc,
                       "end_time" => (event.start_datetime.to_time + event.duration.hours).utc,
                       "isCancelled" => event.archived,
                       "category" => event.flyer_category,
                       "icon" => event.flyer_fa_icon,
                       "virtual_meetup_url" => event.flyer_virtual_meeting_url
                     }
                     response.write(json.to_json)
                  }
                  response.write(']')
                else
                  response.status = 400
                  response.write('{"error":"User not authorized for API usage"}')
                end
              end # get 'cwn_flyer'

              get 'cwn_events' do
                if request.xhr?
                  # respond to Ajax request
                  cwn = Group.where(Sequel.lit("name = 'CoWorking Night: Birmingham'")).first
                  if cwn.nil?
                    redirect '/errors/403'
                  end

                  nextWednesday = Date.parse('Wednesday')
                  delta = nextWednesday > Date.today ? 0 : 7
                  nextWednesday = nextWednesday + delta

                  people = get_user_from_cookies()
                  if people.nil? == false && people.admin
                    time_limit = DateTime.now.utc
                  else
                    time_limit = if (nextWednesday - Date.today) < 4 then nextWednesday else DateTime.now.utc end
                  end
                  group_events = Event.where(Sequel.lit("group_id = ? AND start_datetime > ? AND archived = ?", cwn.id, time_limit, false)).order(:start_datetime).all
                  response.write(group_events.to_json)
                else
                  # respond to normal request
                  redirect '/errors/403'
                end
              end #get cwn_events
            end
          end # expand :restful, :bhm, '/bhm' do

          expand :restful, :groups, '/groups' do
            member do

              expand :restful, :events, '/events' do
                action :list do
                  if request.xhr?
                    # respond to Ajax request
                    nextThursday = Date.parse('Thursday')
                    delta = nextThursday > Date.today ? 0 : 7
                    nextThursday = nextThursday + delta

                    people = get_user_from_cookies()
                    if people.nil? == false && people.admin
                      time_limit = DateTime.now.utc
                    else
                      time_limit = if (nextThursday - Date.today) < 4 then nextThursday else DateTime.now.utc end
                    end

                    group_events = Event.where(Sequel.lit("group_id = ? AND start_datetime > ? AND archived = ?", params[:groups_id], time_limit, false)).all
                    parent_group = Group.where(Sequel.lit("id = ?", params[:groups_id])).first
                    unless parent_group.parent_id.nil?
                      group_events.concat(Event.where(Sequel.lit("group_id = ? AND start_datetime > ? AND archived = ?", parent_group.parent_id, time_limit, false)).all)
                    end
                    response.write(group_events.to_json)
                  else
                    # respond to normal request
                    redirect '/errors/403'
                  end
                end
              end # expand :restful, :events, '/events' do

            end # member do
          end # expand :restful, :groups, '/groups' do


          get 'cwn_flyer' do
            # "approved":true,
            # "cwn":88,
            # "timestamp":"2017-01-09T20:27:22.161Z",
            # "group":"Designer's Corner",
            # "title":"CoWorking Night Tshirt Competition",
            # "description":"Come in to get some last minute ideas for your entry to the CoWorking Night Tshirt competition! ",
            # "date":"2017-01-11T06:00:00.000Z",
            # "time_req_form":"8:00 PM",
            # "time_req":"1899-12-31T01:48:52.000Z",
            # "room_req":"Milky Way Row",
            # "start_time":"2017-01-12T02:00:00.000Z",
            # "end_time":"2017-01-12T03:00:00.000Z",
            # "isCancelled": "false"
            # "category":"Programming",
            # "icon":"terminal"
            if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))

              #For now, we'll keep this only exposed for cwn
              cwn = Group.where(Sequel.lit("name = 'CoWorking Night'")).first
              if cwn.nil?
               redirect '/errors/403'
              end

              #Now lets get all the events for this group. This means all of this group's events and its event's children
              next_cwn_event = Event.where(Sequel.lit("approved = true AND start_datetime > ? AND group_id = ? AND archived = ?", DateTime.now.utc, cwn.id, false)).order(:start_datetime).first

              #check is last cwn_event is still occurring. If it is, then use it
              last_cwn_event = Event.where( Sequel.lit( "approved = true AND start_datetime < ? AND group_id = ? AND archived = ?", DateTime.now.utc, cwn.id, false)).order(:start_datetime).last
              if (((DateTime.now.utc.to_time - last_cwn_event.start_datetime) / 1.hours) < last_cwn_event.duration)
                next_cwn_event = last_cwn_event
              end

              events = get_child_events_for_event(next_cwn_event)
              response.write('[')
              first_time = true
              events.each { |event|
               if first_time == true
                 first_time = false
               else
                 response.write(',')
               end
               json =
                 {
                   "approved" => event.approved,
                   "cwn" => next_cwn_event.instance_number,
                   "timestamp" => event.created_at.utc,
                   "group" => Group.where(Sequel.lit("id = ?", event.group_id)).first.name,
                   "title" => event.name,
                   "description" => event.summary,
                   "date" => event.start_datetime.utc,
                   "time_req_form" => event.start_datetime.utc,
                   "time_req" => event.start_datetime.utc,
                   "room_req" => Venue.where(Sequel.lit("id = ?", event.venue_id)).first.name,
                   "start_time" => event.start_datetime.utc,
                   "end_time" => (event.start_datetime.to_time + event.duration.hours).utc,
                   "isCancelled" => event.archived,
                   "category" => event.flyer_category,
                   "icon" => event.flyer_fa_icon,
                   "virtual_meetup_url" => event.flyer_virtual_meeting_url
                 }
                 response.write(json.to_json)
              }
              response.write(']')
            else
              response.status = 400
              response.write('{"error":"User not authorized for API usage"}')
            end
          end # get 'cwn_flyer'

          get 'cwn_flyer/:cwn_instance_number' do
            # "approved":true,
            # "cwn":88,
            # "timestamp":"2017-01-09T20:27:22.161Z",
            # "group":"Designer's Corner",
            # "title":"CoWorking Night Tshirt Competition",
            # "description":"Come in to get some last minute ideas for your entry to the CoWorking Night Tshirt competition! ",
            # "date":"2017-01-11T06:00:00.000Z",
            # "time_req_form":"8:00 PM",
            # "time_req":"1899-12-31T01:48:52.000Z",
            # "room_req":"Milky Way Row",
            # "start_time":"2017-01-12T02:00:00.000Z",
            # "end_time":"2017-01-12T03:00:00.000Z",
            # "isCancelled": "false"
            # "category":"Programming",
            # "icon":"terminal"

            if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))
              #For now, we'll keep this only exposed for cwn
              cwn = Group.where(Sequel.lit("name = 'CoWorking Night'")).first
              if cwn.nil?
               redirect '/errors/403'
              end

              #Now lets get all the events for this group. This means all of this group's events and its event's children
              cwn_event = Event.where(Sequel.lit("approved = true AND group_id = ? AND instance_number = ? AND archived = ?", cwn.id, params[:cwn_instance_number], false)).order(:start_datetime).first
              events = get_child_events_for_event(cwn_event)
              response.write('[')
              first_time = true
              events.each { |event|
               if first_time == true
                 first_time = false
               else
                 response.write(',')
               end
               json =
                 {
                   "approved" => event.approved,
                   "cwn" => cwn_event.instance_number,
                   "timestamp" => event.created_at.utc,
                   "group" => Group.where(Sequel.lit("id = ?", event.group_id)).first.name,
                   "title" => event.name,
                   "description" => event.summary,
                   "date" => event.start_datetime.utc,
                   "time_req_form" => event.start_datetime.utc,
                   "time_req" => event.start_datetime.utc,
                   "room_req" => Venue.where(Sequel.lit("id = ?", event.venue_id)).first.name,
                   "start_time" => event.start_datetime.utc,
                   "end_time" => (event.start_datetime.to_time + event.duration.hours).utc,
                   "isCancelled" => event.archived,
                   "category" => event.flyer_category,
                   "icon" => event.flyer_fa_icon,
                   "virtual_meetup_url" => event.flyer_virtual_meeting_url
                 }
                 response.write(json.to_json)
              }
              response.write(']')
            else
              response.status = 400
              response.write('{"error":"User not authorized for API usage"}')
            end
          end #get 'cwn_flyer/:cwn_instance_num'

          get 'cwn_events' do
            if request.xhr?
              # respond to Ajax request
              cwn = Group.where(Sequel.lit("name = 'CoWorking Night'")).first
              if cwn.nil?
                redirect '/errors/403'
              end

              nextThursday = Date.parse('Thursday')
              delta = nextThursday > Date.today ? 0 : 7
              nextThursday = nextThursday + delta

              people = get_user_from_cookies()
              if people.nil? == false && people.admin
                time_limit = DateTime.now.utc
              else
                time_limit = if (nextThursday - Date.today) < 4 then nextThursday else DateTime.now.utc end
              end
              group_events = Event.where(Sequel.lit("group_id = ? AND start_datetime > ? AND archived = ?", cwn.id, time_limit, false)).order(:start_datetime).all
              response.write(group_events.to_json)
            else
              # respond to normal request
              redirect '/errors/403'
            end
          end #get cwn_events

          get 'all_cwn_events' do
            if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))
              group = Group.where(Sequel.lit("name = 'CoWorking Night'")).first
              time = DateTime.now.utc
              events = Event.where(Sequel.lit("group_id = ?", group.id)).order(:start_datetime).all

              response.write('[')
              first_time = true
              events.each { |event|
               if first_time == true
                 first_time = false
               else
                 response.write(',')
               end
               json =
                 {
                   "name" => event.name,
                   "date" => event.start_datetime.utc,
                   "location" => Venue.where(Sequel.lit("id = ?", event.venue_id)).first.name,
                 }
                 response.write(json.to_json)
              }
              response.write(']')
            else
              response.status = 400
              response.write('{"error":"User not authorized for API usage"}')
            end
          end

          # temporary until the new flyer is up
          get 'cwn_future' do
            if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))
              group = Group.where(Sequel.lit("name = 'CoWorking Night'")).first
              time = DateTime.now.utc
              events = Event.where(Sequel.lit("group_id = ? AND start_datetime > ? AND archived = ?", group.id, time, false)).order(:start_datetime).all

              response.write('[')
              first_time = true
              events.each { |event|
               if first_time == true
                 first_time = false
               else
                 response.write(',')
               end
               json =
                 {
                   "name" => event.name,
                   "date" => event.start_datetime.utc,
                   "location" => Venue.where(Sequel.lit("id = ?", event.venue_id)).first.name,
                 }
                 response.write(json.to_json)
              }
              response.write(']')
            else
              response.status = 400
              response.write('{"error":"User not authorized for API usage"}')
            end
          end

          get 'next_cwn_number' do
            if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))
              #For now, we'll keep this only exposed for cwn
              cwn = Group.where(Sequel.lit("name = 'CoWorking Night'")).first
              if cwn.nil?
               response.status = 404
               response.write('{"error":"No CoWorking events scheduled"}')
              else
                #Now lets get all the events for this group. This means all of this group's events and its event's children
                next_cwn_event = Event.where(Sequel.lit("approved = true AND start_datetime > ? AND group_id = ? AND archived = ?", DateTime.now.utc, cwn.id, false)).order(:start_datetime).first

                #check is last cwn_event is still occurring. If it is, then use it
                last_cwn_event = Event.where(Sequel.lit("approved = true AND start_datetime < ? AND group_id = ? AND archived = ?", DateTime.now.utc, cwn.id, false)).order(:start_datetime).last
                if (((DateTime.now.utc.to_time - last_cwn_event.start_datetime) / 1.hours) < last_cwn_event.duration)
                  next_cwn_event = last_cwn_event
                end

                response.write('{"cwnNumber":' + next_cwn_event.id.to_s + '}')
              end
            else
              response.status = 400
              response.write('{"error":"User not authorized for API usage"}')
            end
          end


          get 'thisweeks_cwn_event' do
            if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))
              #For now, we'll keep this only exposed for cwn
              cwn = Group.where(Sequel.lit("name = 'CoWorking Night'")).first
              if cwn.nil?
               response.status = 404
               response.write('{"error":"No CoWorking events scheduled"}')
              else
                #Now lets get all the events for this group. This means all of this group's events and its event's children
                next_cwn_event = Event.where(Sequel.lit("approved = true AND start_datetime > ? AND group_id = ? AND archived = ?", DateTime.now.utc, cwn.id, false)).order(:start_datetime).first

                #check is last cwn_event is still occurring. If it is, then use it
                last_cwn_event = Event.where(Sequel.lit("approved = true AND start_datetime < ? AND group_id = ? AND archived = ?", DateTime.now.utc, cwn.id, false)).order(:start_datetime).last
                if (((DateTime.now.utc.to_time - last_cwn_event.start_datetime) / 1.hours) < last_cwn_event.duration)
                  next_cwn_event = last_cwn_event
                end
                json =
                  {
                    "id" => next_cwn_event.id,
                    "approved" => next_cwn_event.approved,
                    "cwn" => next_cwn_event.instance_number,
                    "timestamp" => next_cwn_event.created_at.utc,
                    "group" => Group.where(Sequel.lit("id = ?", next_cwn_event.group_id)).first.name,
                    "title" => next_cwn_event.name,
                    "description" => next_cwn_event.summary,
                    "date" => next_cwn_event.start_datetime.utc,
                    "time_req_form" => next_cwn_event.start_datetime.utc,
                    "time_req" => next_cwn_event.start_datetime.utc,
                    "room_req" => Venue.where(Sequel.lit("id = ?", next_cwn_event.venue_id)).first.name,
                    "start_time" => next_cwn_event.start_datetime.utc,
                    "end_time" => (next_cwn_event.start_datetime.to_time + next_cwn_event.duration.hours).utc,
                    "category" => next_cwn_event.flyer_category,
                    "icon" => next_cwn_event.flyer_fa_icon,
                    "virtual_meetup_url" => next_cwn_event.flyer_virtual_meeting_url
                  }
                  response.write(json.to_json)
              end
            else
              response.status = 400
              response.write('{"error":"User not authorized for API usage"}')
            end
          end

          get 'nextweeks_cwn_event' do
            if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))
              #For now, we'll keep this only exposed for cwn
              cwn = Group.where(Sequel.lit("name = 'CoWorking Night'")).first
              if cwn.nil?
               response.status = 404
               response.write('{"error":"No CoWorking events scheduled"}')
              else
                #Now lets get all the events for this group. This means all of this group's events and its event's children
                next_cwn_event = Event.where(Sequel.lit("approved = true AND start_datetime > ? AND group_id = ? AND archived = ?", DateTime.now.utc, cwn.id, false)).order(:start_datetime).first(2)[1]

                json =
                  {
                    "id" => next_cwn_event.id,
                    "approved" => next_cwn_event.approved,
                    "cwn" => next_cwn_event.instance_number,
                    "timestamp" => next_cwn_event.created_at.utc,
                    "group" => Group.where(Sequel.lit("id = ?", next_cwn_event.group_id)).first.name,
                    "title" => next_cwn_event.name,
                    "description" => next_cwn_event.summary,
                    "date" => next_cwn_event.start_datetime.utc,
                    "time_req_form" => next_cwn_event.start_datetime.utc,
                    "time_req" => next_cwn_event.start_datetime.utc,
                    "room_req" => Venue.where(Sequel.lit("id = ?", next_cwn_event.venue_id)).first.name,
                    "start_time" => next_cwn_event.start_datetime.utc,
                    "end_time" => (next_cwn_event.start_datetime.to_time + next_cwn_event.duration.hours).utc,
                    "category" => next_cwn_event.flyer_category,
                    "icon" => next_cwn_event.flyer_fa_icon,
                    "virtual_meetup_url" => next_cwn_event.flyer_virtual_meeting_url
                  }
                  response.write(json.to_json)
              end
            else
              response.status = 400
              response.write('{"error":"User not authorized for API usage"}')
            end
          end

          get 'users' do
            if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))
              users = People.where(Sequel.lit("opt_in = TRUE AND approved = TRUE AND email IS NOT NULL")).all
              response.write('[')
              first_time = true
              users.each { |user|
               if first_time == true
                 first_time = false
               else
                 response.write(',')
               end
               if user.first_name.to_s.empty? || user.last_name.to_s.empty?
                json = {
                  "email" => user.email,
                  "name" => user.email
                }
               else
                json =
                  {
                    "email" => user.email,
                    "name" => user.first_name + " " + user.last_name
                  }
                end
                response.write(json.to_json)
              }
              response.write(']')
            else
              response.status = 400
              response.write('{"error":"User not authorized for API usage"}')
            end
          end

          post 'checkin' do
            if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))
              body = request.body.read
              json = JSON.parse(body)
              email = json["email"]
              event = Event.where( Sequel.lit("id = ?", json["event"] ) ).first
              person = People.where( Sequel.lit("lower(email) = ?", email.downcase ) ).first
              if event.nil?
                  response.status = 404
                  response.write('{"error":"Event not found"}')
              else
                # check to make sure the event is active
                # if the event is active, check if the user exists
                #   if the user does not exist, try to create the user
                #   if the user does exist, make sure the has not already checked in
                current_time = DateTime.now.utc
                event_start_time = (event.start_datetime.to_time - 12.hours).utc #Give 12 hour leeway to checkin
                event_end_time = (event.start_datetime.to_time + event.duration.hours).utc
                event_is_active = event_start_time < current_time && event_end_time > current_time

                if event_is_active == false
                  #event is not active
                  response.status = 400
                  response.write('{"error":"Event is not active"}')
                elsif person.nil?
                  # user does not exist, create the user, check him in, create an auth token, and send the user an email
                  if is_valid_email(email)
                    first_name = json["first_name"]
                    last_name = json["last_name"]
                    if first_name.nil? || first_name.empty?
                      response.status = 400
                      response.write('{"error":"Invalid first name"}')
                    elsif last_name.nil? || last_name.empty?
                      response.status = 400
                      response.write('{"error":"Invalid last name"}')
                    else
                      p_params =
                      {
                        "email" => email,
                        "first_name" => first_name,
                        "last_name" => last_name,
                        "approved" => false,
                        "opt_in" => true,
                        "opt_in_time" => Time.now.utc
                      }
                      person = People.new(p_params)
                      person.save

                      custom_url = first_name + "-" + last_name + "-" + person.id.to_s
                      if unique_url(person.id, custom_url)
                        if slug_contains_invalid(custom_url)
                          person.custom_url = SecureRandom.uuid
                        else
                          person.custom_url = custom_url
                        end
                      else
                        person.custom_url = SecureRandom.uuid
                      end
                      person.save

                      send_checkin_acct_creation_email(person)

                      c_params =
                      {
                        "event_id" => event.id,
                        "people_id" => person.id
                      }
                      checkin = Checkin.new(c_params)
                      checkin.save

                      gibbon = Gibbon::Request.new
                      puts gibbon.lists('4e8bac9c1c').members.retrieve.inspect
                      puts gibbon.lists('4e8bac9c1c').interest_categories.retrieve.inspect
                      begin
                        gibbon.lists('4e8bac9c1c').members.create(body: {email_address: person.email, status: "subscribed", merge_fields: {FNAME: person.first_name, LNAME: person.last_name}})
                      rescue Gibbon::MailChimpError => exception
                        puts exception.inspect
                      end
                      response.status = 201
                      execute_webhooks_with_person(person)
                    end
                  else
                    response.status = 400
                    response.write('{"error":"Invalid email address"}')
                  end
                else
                  # event is active and user already exists; make sure this isn't a duplicate checkin
                  existing_checkin = Checkin.where( Sequel.lit( "people_id = ? AND event_id = ?", person.id, event.id ) ).first
                  if existing_checkin.nil? == false
                    response.status = 400
                    response.write('{"error":"User has already checked in"}')
                  else
                    c_params =
                      {
                        "event_id" => event.id,
                        "people_id" => person.id
                      }
                    checkin = Checkin.new(c_params)
                    checkin.save
                    response.status = 201
                    execute_webhooks_with_person(person)

                    if person.approved == false
                      send_checkin_acct_creation_email(person)

                      gibbon = Gibbon::Request.new
                      #puts gibbon.lists('4e8bac9c1c').members.retrieve.inspect
                      #puts gibbon.lists('4e8bac9c1c').interest_categories.retrieve.inspect
                      begin
                        gibbon.lists('4e8bac9c1c').members.create(body: {email_address: person.email, status: "subscribed", merge_fields: {FNAME: person.first_name, LNAME: person.last_name}})
                      rescue Gibbon::MailChimpError => exception
                        puts exception.inspect
                      end
                    end
                  end
                end
              end
            else
              response.status = 400
              response.write('{"error":"User not authorized for API usage"}')
            end
          end

          # envoke the webooks with some json
          post 'webhooks/execute' do
            if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))
              response.status = 200
              response.headers['Content-Type'] = 'application/json'
              body = request.body.read
              json = JSON.parse(body)

              person = People.where( Sequel.lit( "id = ?", json["id"] ) ).first
              if person.nil?
                response.status = 404
                response.write('{"error":"User not found"}')
              else
                execute_webhooks_with_person(person)
                response.write(json.to_json)
              end
            else
              response.status = 400
              response.write('{"error":"User not authorized for API usage"}')
            end
          end

          # create the webhook for checkins
          post 'checkin/webhook' do
            if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))
              response.status = 200
              response.headers['Content-Type'] = 'application/json'
              body = request.body.read
              json = JSON.parse(body)
              params =
                {
                  "url" => json["url"],
                  "created_at" => DateTime.now.utc
                }
              webhook = Webhook.new(params)
              webhook.save
              response.write( json.to_json )
            else
              response.status = 400
              response.write('{"error":"User not authorized for API usage"}')
            end
          end
        end # collection do
      end # expand :restful, :v1, '/v1' do

      expand :restful, :v2, '/v2' do
        collection do
          expand :restful, :flyer, '/flyer' do
            get '/group/:id' do
              # {
              #   "cwn: {
              #     "approved": true,
              #     "isCancelled": "false",
              #     "instance_number": 88,
              #     "start_time":"2017-01-12T02:00:00.000Z",
              #     "end_time":"2017-01-12T03:00:00.000Z",
              #     "workshops": [
              #       {
              #         "approved": true,
              #         "isCancelled": "false",
              #         "group":"Designer's Corner",
              #         "title":"CoWorking Night Tshirt Competition",
              #         "description":"Come in to get some last minute ideas for your entry to the CoWorking Night Tshirt competition! ",
              #         "date":"2017-01-11T06:00:00.000Z",
              #         "room":"Milky Way Row",
              #         "start_time":"2017-01-12T02:00:00.000Z",
              #         "end_time":"2017-01-12T03:00:00.000Z",
              #         "category":"Programming",
              #         "icon":"terminal"
              #       }
              #     ]
              #   }
              # }
              if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))
                # Get all CoWorking Night events
                next_cwn_event = Event.where(Sequel.lit("approved = ? AND start_datetime > ? AND group_id = ? AND archived = ?", true, DateTime.now.utc, params[:id], false)).order(:start_datetime).first

                # Check if last cwn_event is still occurring. If it is, then use it
                last_cwn_event = Event.where(Sequel.lit("approved = ? AND start_datetime < ? AND group_id = ? AND archived = ?", true, DateTime.now.utc, params[:id], false)).order(:start_datetime).last
                unless last_cwn_event.nil?
                  if (((DateTime.now.utc.to_time - last_cwn_event.start_datetime) / 1.hours) < last_cwn_event.duration)
                    next_cwn_event = last_cwn_event
                  end
                end

                if next_cwn_event.nil?
                  json = {
                    "message": "This event has not yet been scheduled. Please check back soon or visit the CoWorking Night Facebook page (https://www.facebook.com/urbanenginecoworkingnight/) for updates.",
                    "cwn": {}
                  }
                  response.status = 200
                  response.headers['Content-Type'] = 'application/json'
                  response.write( json.to_json )
                else
                  json = {}
                  child_events = Event.where(Sequel.lit("parent_id = ? AND approved = ?", next_cwn_event.id, true)).all

                  if child_events.empty?
                    # no events have been scheduled (approved) at this time
                    json = {
                      "message": "The schedule is not yet available. Please check back soon.",
                      "cwn": {
                        "approved" => next_cwn_event.approved,
                        "isCancelled" => next_cwn_event.archived,
                        "instance_number" => next_cwn_event.instance_number,
                        "start_time" => next_cwn_event.start_datetime.utc,
                        "end_time" => (next_cwn_event.start_datetime.to_time + next_cwn_event.duration.hours).utc,
                        "location" => Venue.where( Sequel.lit( "id = ?", next_cwn_event.venue_id ) ).first.name,
                        "workshops" => []
                      }
                    }

                    response.status = 200
                    response.headers['Content-Type'] = 'application/json'
                    response.write( json.to_json )
                  else
                    workshops = []
                    for child_event in child_events do
                      puts child_event.to_json
                      workshop = {
                        "approved" => child_event.approved,
                        "isCancelled" => child_event.archived,
                        "group" => Group.where(Sequel.lit("id = ?", child_event.group_id)).first.name,
                        "title" => child_event.name,
                        "description" => child_event.summary,
                        "date" => child_event.start_datetime.utc,
                        "room" => Venue.where(Sequel.lit("id = ?", child_event.venue_id)).first.name,
                        "start_time" => child_event.start_datetime.utc,
                        "end_time" => (child_event.start_datetime.to_time + child_event.duration.hours).utc,
                        "category" => child_event.flyer_category,
                        "icon" => child_event.flyer_fa_icon,
                        "virtual_meetup_url" => child_event.flyer_virtual_meeting_url
                      }
                      workshops.push( workshop )
                    end # for in

                    json = {
                      "message": "",
                      "cwn": {
                        "approved" => next_cwn_event.approved,
                        "isCancelled" => next_cwn_event.archived,
                        "instance_number" => next_cwn_event.instance_number,
                        "start_time" => next_cwn_event.start_datetime.utc,
                        "end_time" => (next_cwn_event.start_datetime.to_time + next_cwn_event.duration.hours).utc,
                        "location" => Venue.where( Sequel.lit( "id = ?", next_cwn_event.venue_id ) ).first.name,
                        "workshops" => workshops
                      }
                    }

                    response.status = 200
                    response.headers['Content-Type'] = 'application/json'
                    response.write( json.to_json )
                end # if else
                end # else
              else
                # respond to normal request
                redirect '/errors/403'
              end # if else
            end # expand :restful :group, '/group' do
          end # expand :restful, :flyer, '/flyer' do

          post 'checkin' do
            if (request.env["HTTP_AUTHORIZATION"] && api_key_is_authenticated(request.env["HTTP_AUTHORIZATION"]))
              json = JSON.parse( request.body.read )
              auth0Id = json["auth0Id"]
              eventId = json["eventId"]
              event = Event.where( Sequel.lit( "id = ?", eventId ) ).first
              person = People.where( Sequel.lit( "auth0_id = ?", auth0Id ) ).first

              if event.nil?
                  response.status = 400
                  response.write( '{"message":"Event does not exist", "success":false}' )
                  response.headers['Content-Type'] = 'application/json'
              else
                # check to make sure the event is active
                # if the event is active, check if the user exists
                #   if the user does not exist, try to create the user
                #   if the user does exist, make sure the has not already checked in
                current_time = DateTime.now.utc
                event_start_time = (event.start_datetime.to_time - 3.hours).utc # Give hour leeway to checkin
                event_end_time = (event.start_datetime.to_time + event.duration.hours).utc
                event_is_active = event_start_time < current_time && event_end_time > current_time

                if event_is_active == false
                  # event is not active
                  response.status = 400
                  response.write('{"message": "Event is not active", "success": false}')
                  response.headers[ 'Content-Type' ] = 'application/json'
                elsif person.nil?
                    response.status = 400
                    response.write( '{"message": "User does not exist", "success": false}' )
                    response.headers[ 'Content-Type' ] = 'application/json'
                else
                  # event is active and user already exists; make sure this isn't a duplicate checkin
                  existing_checkin = Checkin.where( Sequel.lit( "people_id = ? AND event_id = ?", person.id, event.id ) ).first
                  if existing_checkin.nil? == false
                    response.status = 400
                    response.write( '{"message": "User has already checked in", "success": false}' )
                    response.headers[ 'Content-Type' ] = 'application/json'
                  else
                    c_params =
                      {
                        "event_id" => event.id,
                        "people_id" => person.id
                      }
                    checkin = Checkin.new(c_params)
                    checkin.save
                    execute_webhooks_with_person(person)
                    response.status = 200
                    response.write('{"message":"Checkin successful", "success":true}')
                    response.headers['Content-Type'] = 'application/json'

                    if person.approved == false
                      send_checkin_acct_creation_email(person)

                      gibbon = Gibbon::Request.new
                      #puts gibbon.lists('4e8bac9c1c').members.retrieve.inspect
                      #puts gibbon.lists('4e8bac9c1c').interest_categories.retrieve.inspect
                      begin
                        gibbon.lists('4e8bac9c1c').members.create(body: {email_address: person.email, status: "subscribed", merge_fields: {FNAME: person.first_name, LNAME: person.last_name}})  
                      rescue Gibbon::MailChimpError => exception
                        puts exception.inspect
                      end
                    end
                  end
                end
              end
            else
              response.status = 401
              response.write('{"message":"User not authorized for API usage", "success":false}')
              response.headers['Content-Type'] = 'application/json'
            end
          end # /checkin
        end # collection do
      end # expand :restful :v2 '/v2' do
    end # collection do
  end # expand :restful, :api, '/api' do
end # Pakyow::App.routes(:api) do
