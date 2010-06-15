module HasGlobalSession
  module ActionControllerInstanceMethods
    def global_session
      return @global_session if @global_session

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
      rescue Exception => e
        #silently recover from any error by initializing a new global session;
        #the new session will be unauthenticated.
        directory.report_exception(e, cookie)
        logger.error "#{e.class.name}: #{e.message} (at #{e.backtrace[0]})" if logger
        @global_session = GlobalSession.new(directory)
      end
    end

    if Configuration['integrated']
      def session
        @integrated_session ||= IntegratedSession.new(super, global_session)
        return @integrated_session
      end
    end

    def global_session_update_cookie
      return unless @global_session
      name   = Configuration['cookie']['name']
      domain = Configuration['cookie']['domain']

      #Default options for invalid session
      options = {:value   => nil,
                 :domain  => domain,
                 :expires => Time.at(0)}

      if @global_session.valid?
        begin
          value   = @global_session.to_s 
          expires = Configuration['ephemeral'] ? nil : @global_session.expired_at          
          options.merge!(:value => value, :expires => expires)
        rescue Exception => e
          logger.error "#{e.class.name}: #{e.message} (at #{e.backtrace[0]})" if logger
        end
      end

      cookies[name] = options unless (cookies[name] == options[:value])
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
