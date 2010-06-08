module HasGlobalSession
  module ActionControllerInstanceMethods
    def global_session
      return @global_session if @global_session

      begin
        if (klass = Configuration['directory'])
          klass = klass.constantize
        else
          klass = Directory
        end

        directory = klass.new(File.join(RAILS_ROOT, 'config', 'authorities'))
        cookie = cookies[Configuration['cookie']['name']]

        begin
          #unserialize the global session from the cookie, or
          #initialize a new global session if cookie == nil
          @global_session = GlobalSession.new(directory, cookie)
        rescue SessionExpired
          #if the cookie is present but expired, silently
          #initialize a new global session
          @global_session = GlobalSession.new(directory)
        end
      rescue Exception => e
        cookies.delete Configuration['cookie']['name']
        raise e
      end
    end

    if Configuration['integrated']
      def session
        @integrated_session ||= IntegratedSession.new(super, global_session)
        return @integrated_session
      end
    end

    def global_session_update_cookie
      if @global_session
        if @global_session.expired?
          options = {:value   => nil,
                     :domain  => Configuration['cookie']['domain'],
                     :expires => Time.at(0)}
        else
          options = {:value   => @global_session.to_s,
                     :domain  => Configuration['cookie']['domain'],
                     :expires => @global_session.expires_at}
        end

        cookies[Configuration['cookie']['name']] = options
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
