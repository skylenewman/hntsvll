require 'date'
Pakyow::App.routes(:events) do
  include SharedRoutes

  expand :restful, :events, '/events', :before => :route_head do

    collection do
      # GET /events/manage;
      get 'manage', :before => :is_hsv_event_manager do
        events_all = []
  		  people = get_user_from_cookies()
        if people.nil?
          redirect '/errors/404'
        end
        if people.admin
          cwnbhm = Group.where(Sequel.lit("name = 'CoWorking Night: Birmingham'")).first
          cwnbhmevents = Group.where(Sequel.lit("name = 'CoWorking Night Events: Birmingham'")).first
          events_all = Event.where(Sequel.lit('start_datetime > ?', DateTime.now.utc)).where(Sequel.lit('archived = ?', false))
                        .where(Sequel.lit('group_id != ? and group_id != ?', cwnbhm.id, cwnbhmevents.id)).all
        else
          people.groups().each { |group|
            if group.name == 'CoWorking Night: Birmingham' || group.name == 'CoWorking Night Events: Birmingham'
              next
            end
            events = Event.where(Sequel.lit('group_id = ?', group.id)).where(Sequel.lit('start_datetime > ?', DateTime.now.utc)).where(Sequel.lit('archived = ?', false)).all
            events.each { |event|
              events_all.push(event)
            }
          }
        end
        view.scope(:people).bind(people)
        view.scope(:events).apply(events_all)
        current_user = get_user_from_cookies()
        view.scope(:optin).apply(current_user)
        view.scope(:head).apply(request)
        view.scope(:main_menu).apply(request)
      end

      get 'approve/:events_id', :before => :is_admin_check do
        success = 'failure'
        if params[:events_id].is_number? == false
          redirect "/errors/404"
        end
        event = Event[params[:events_id]]
        if event.nil?
          redirect "/errors/404"
        end
        event.approved = true
        previous_event = Event.where(Sequel.lit("approved = true AND group_id = ? AND start_datetime < ?", event.group_id, event.start_datetime)).order(:start_datetime).last
        instance_number = 1
        unless previous_event.nil?
          instance_number = previous_event.instance_number + 1
        end
        readjust_event_instance_number_for_group(event.start_datetime, event.group_id)
        event.instance_number = instance_number
        event.save
        if request.xhr?
          success = 'success'
        else
          redirect request.referer
        end
        send success
      end

      get 'unapprove/:events_id', :before => :is_admin_check do
        success = 'failure'
        if params[:events_id].is_number? == false
          redirect "/errors/404"
        end
        event = Event[params[:events_id]]
        if event.nil?
          redirect "/errors/404"
        end
        event.approved = false
        event.instance_number = nil
        readjust_event_instance_number_for_group(event.start_datetime, event.group_id)
        event.save
        if request.xhr?
          success = 'success'
        else
          redirect request.referer
        end
        send success
      end
    end

    member do
      #TODO: DELETE '/events/:events_id' route. This is a workaround
      # GET ''/events/:events_id/delete'
      get 'delete' do
        if params[:events_id].is_number? == false
          redirect "/errors/404"
        end
        event = Event.where(Sequel.lit("id = ?", params[:events_id])).first
        if event.nil?
          redirect "/errors/404"
        end
        people = get_user_from_cookies()
        isNotSiteAdmin = people != nil && people.admin != nil && people.admin == false
        if event.approved && isNotSiteAdmin
          redirect "/errors/404"
        end
        if logged_in_user_is_manager_of_event(event) == false
          redirect "/errors/403"
        end
        event_start_datetime = event.start_datetime
        event_group_id = event.group_id
        event_is_approved = event.approved
        event.archived = true
        if event_is_approved
          readjust_event_instance_number_for_group(event_start_datetime, event_group_id)
        end
        event.save
        redirect '/events/manage'
      end
    end

    # GET /events; same as Index
    action :list do
      people = get_user_from_cookies()
      if people.nil?
        redirect '/errors/404'
      end
      events_all = []
      people.groups().each { |group|
        events = Event.where(Sequel.lit('group_id = ?', group.id)).all
        events.each { |event|
          events_all.push(event)
        }
      }
      view.scope(:events).apply(events_all)
      current_user = get_user_from_cookies()
      view.scope(:optin).apply(current_user)
      view.scope(:head).apply(request)
      view.scope(:main_menu).apply(request)
    end

    # GET /events/:events_id
    action :show do
      people = get_user_from_cookies()
      if people.nil?
        redirect '/errors/404'
      end
      if params[:events_id].is_number? == false
        redirect "/errors/404"
      end
      event = Event.where(Sequel.lit("id = ?", params[:events_id])).first
      if event.nil?
        redirect "/errors/404"
      end
      view.scope(:people).bind(people)
      view.scope(:events).apply([event, event])
      current_user = get_user_from_cookies()
      view.scope(:optin).apply(current_user)
      view.scope(:head).apply(request)
      view.scope(:main_menu).apply(request)
    end

    # GET '/events/new'
    action :new, :before => :is_hsv_event_manager do
      people = get_user_from_cookies()
      if people.nil?
        redirect '/errors/404'
      end
      view.scope(:events).with do
        bind(Event.new)
      end
      view.scope(:people).bind(people)
      current_user = get_user_from_cookies()
      view.scope(:optin).apply(current_user)
      view.scope(:head).apply(request)
      view.scope(:main_menu).apply(request)
    end

    #POST '/events/'
    action :create, :before => :is_hsv_event_manager do
      people = get_user_from_cookies()
      if people.nil?
        redirect '/errors/404'
      end
      parsed_time = DateTime.strptime(params[:events][:start_datetime] + "-0600", '%b %d, %Y %I:%M %p %Z')
      previous_event = Event.where(Sequel.lit("approved = true AND group_id = ? AND start_datetime < ?", params[:events][:parent_group].to_i, parsed_time.to_datetime.utc)).order(:start_datetime).last
      instance_number = 1
      unless previous_event.nil?
        instance_number = previous_event.instance_number + 1
      end
      group = Group.where(Sequel.lit("id = ?", params[:events][:parent_group].to_i)).first
      c_params =
        {
          "name" => params[:events][:name],
          "summary" => params[:events][:summary],
          "description" => params[:events][:description],
          "group_id" => params[:events][:parent_group].to_i,
          "start_datetime" => parsed_time.to_datetime.utc,
          "duration" => params[:events][:duration].to_i,
          "venue_id" => params[:events][:venue].to_i,
          "approved" => if people.admin then true else false end,
          "instance_number" => instance_number,
          "parent_id" => if params[:events][:parent_event_selector].blank? then "" else params[:events][:parent_event_selector].to_i end,
          "flyer_category" => if params[:events][:flyer_category].nil? || params[:events][:flyer_category].empty? then group.flyer_category else params[:events][:flyer_category] end,
          "flyer_fa_icon" => if params[:events][:flyer_fa_icon].nil? || params[:events][:flyer_fa_icon].empty? then group.flyer_fa_icon else params[:events][:flyer_fa_icon] end,
          "flyer_virtual_meeting_url" => params[:events][:flyer_virtual_meeting_url],
          "created_by" => people.id,
          "updated_by" => people.id
        }
      event = Event.new(c_params)
      event.save
      if event.approved
        readjust_event_instance_number_for_group(event.start_datetime, event.group_id)
      end
      redirect '/events/manage'
    end

    #PATCH '/events/:events_id'
    action :update, :before => :is_hsv_event_manager do
      people = get_user_from_cookies()
      if people.nil?
        redirect '/errors/404'
      end
      if params[:events][:id].is_number? == false
        redirect "/errors/404"
      end
      event = Event.where(Sequel.lit("id = ?", params[:events][:id])).first
      if event.nil?
        redirect "/errors/404"
      end
      if logged_in_user_is_manager_of_event(event) == false
        redirect "/errors/403"
      end
      parsed_datetime = DateTime.strptime(params[:events][:start_datetime] + "-0600", '%b %d, %Y %I:%M %p %Z')
      venue_id = params[:events][:venue].to_i
      minutes_between_old_and_new_date = (((parsed_datetime - event.start_datetime.to_datetime)*24*60).to_i).abs
      if event.approved && minutes_between_old_and_new_date > 0.99
        readjust_event_instance_number_for_group(event.start_datetime, event.group_id)
      end

      if people.admin == false && (minutes_between_old_and_new_date > 0.99 || venue_id != event.venue_id)
        event.approved = false
      end
      unless event.approved
        event.instance_number = nil
      end
      event.name = params[:events][:name]
      event.description = params[:events][:description]
      event.summary = params[:events][:summary]
      event.group_id = params[:events][:parent_group].to_i
      event.start_datetime = parsed_datetime.to_datetime.utc
      event.duration = params[:events][:duration].to_i
      if params[:events][:parent_event_selector].blank?
        event.parent_id = nil
      else
        event.parent_id = params[:events][:parent_event_selector].to_i
      end
      event.venue_id = venue_id
      event.flyer_category = params[:events][:flyer_category]
      event.flyer_fa_icon = params[:events][:flyer_fa_icon]
      event.flyer_virtual_meeting_url = params[:events][:flyer_virtual_meeting_url]
      event.updated_by = people.id
      event.save
      redirect '/events/manage'
    end

    # GET '/events/:events_id/edit'
    action :edit, :before => :is_hsv_event_manager do
      people = get_user_from_cookies()
      if people.nil?
        redirect '/errors/404'
      end
      if params[:events_id].is_number? == false
        redirect "/errors/404"
      end
      event = Event.where(Sequel.lit("id = ?", params[:events_id])).first
      if event.nil?
        redirect "/errors/404"
      end
      if logged_in_user_is_manager_of_event(event) == false
        redirect "/errors/403"
      end
      view.scope(:events).bind([event, event, event])
      view.scope(:people).bind(people)
      current_user = get_user_from_cookies()
      view.scope(:optin).apply(current_user)
      view.scope(:head).apply(request)
      view.scope(:main_menu).apply(request)
    end
  end
end
