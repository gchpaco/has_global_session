module HasGlobalSession
  module ActionControllerInstanceMethods
    def self.included(base)
      if Configuration['integrated']
        base.alias_method_chain :session, :global_session
      end
    end

    def global_session
      @global_session
    end

    def session_with_global_session
      if global_session
        @integrated_session ||= IntegratedSession.new(session_without_global_session, global_session)
        return @integrated_session
      else
        return session_without_global_session
      end
    end

    def global_session_read_cookie
      if (klass = Configuration['directory'])
        klass = klass.constantize
      else
        klass = Directory
      end

      directory = klass.new(File.join(RAILS_ROOT, 'config', 'authorities'))
      cookie_name = Configuration['cookie']['name']
      cookie      = cookies[cookie_name]

      begin
        #unserialize the global session from the cookie, or
        #initialize a new global session if cookie == nil
        @global_session = GlobalSession.new(directory, cookie)
        return true
      rescue Exception => e
        #silently recover from any error by initializing a new global session
        @global_session = GlobalSession.new(directory)
        global_session_update_cookie
        #give the Rails app a chance to handle the exception
        raise e
      end
    end

    def global_session_update_cookie
      name   = Configuration['cookie']['name']
      domain = Configuration['cookie']['domain']

      begin
        if @global_session && @global_session.valid?
          value   = @global_session.to_s
          expires = Configuration['ephemeral'] ? nil : @global_session.expired_at
          
          unless (cookies[name] == value)
            #Update the cookie only if its value has changed
            cookies[name] = {:value => value, :domain=>domain, :expires=>expires}
          end
        end

        raise HasGlobalSession::InvalidSession, "buahahaha" if params[:moo]
      rescue Exception => e
        #silently recover from any error by wiping the cookie
        cookies[name] = {:value=>nil, :domain=>domain, :expires=>Time.at(0)}
        #give the Rails app a chance to handle the exception
        raise e
      end
    end

    def log_processing
      if logger && logger.info?
        log_processing_for_request_id
        log_processing_for_parameters
      end
    end

    def log_processing_for_request_id()
      if global_session && global_session.id
        session_id = global_session.id + " (#{session[:session_id]})"
      elsif session[:session_id]
        session_id = session[:session_id]
      elsif request.session_options[:id]
        session_id = request.session_options[:id]
      end

      request_id = "\n\nProcessing #{self.class.name}\##{action_name} "
      request_id << "to #{params[:format]} " if params[:format]
      request_id << "(for #{request_origin.split[0]}) [#{request.method.to_s.upcase}]"
      request_id << "\n  Session ID: #{session_id}" if session_id

      logger.info(request_id)
    end

    def log_processing_for_parameters
      parameters = respond_to?(:filter_parameters) ? filter_parameters(params) : params.dup
      parameters = parameters.except!(:controller, :action, :format, :_method)

      logger.info "  Parameters: #{parameters.inspect}" unless parameters.empty?
    end
  end
end
