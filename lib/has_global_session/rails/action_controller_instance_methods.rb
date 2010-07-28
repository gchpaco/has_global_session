module HasGlobalSession
  # Rails integration for HasGlobalSession.
  #
  # The configuration file for Rails apps is located in +config/global_session.yml+ and a generator
  # (global_session_config) is available for creating a sensible default.
  #
  # There is also a generator (global_session_authority) for creating authority keypairs.
  #
  # The main integration touchpoint for Rails is the module ActionControllerInstanceMethods,
  # which gets mixed into ActionController::Base. This is where all of the magic happens..
  #
  module Rails
    # Module that is mixed into ActionController-derived classes when the class method
    # +has_global_session+ is called.
    #
    module ActionControllerInstanceMethods
      def self.included(base) # :nodoc:
        base.alias_method_chain :session, :global_session
        base.before_filter :global_session_read_cookie
        base.before_filter :global_session_auto_renew
        base.after_filter  :global_session_update_cookie
      end

      # Global session reader.
      #
      # === Return
      # session(GlobalSession):: the global session associated with the current request, nil if none
      def global_session
        @global_session
      end

      # Aliased version of ActionController::Base#session which will return the integrated
      # global-and-local session object (IntegratedSession).
      #
      # === Return
      # session(IntegratedSession):: the integrated session
      def session_with_global_session
        if Configuration['integrated'] && @global_session
          unless @integrated_session &&
                 (@integrated_session.local == session_without_global_session) && 
                 (@integrated_session.global == @global_session)
            @integrated_session =
              IntegratedSession.new(session_without_global_session, @global_session)
          end
          
          return @integrated_session
        else
          return session_without_global_session
        end
      end

      # Before-filter to read the global session cookie and construct the GlobalSession object
      # for this controller instance.
      #
      # === Return
      # true:: Always returns true
      def global_session_read_cookie
        directory   = global_session_create_directory
        cookie_name = Configuration['cookie']['name']
        cookie      = cookies[cookie_name]

        begin
          cached_digest = session_without_global_session[:_session_gbl_valid_sig]

          #unserialize the global session from the cookie, or
          #initialize a new global session if cookie == nil.
          #
          #pass along the cached trusted signature (if any) so the new object
          #can skip the expensive RSA Decrypt operation.
          @global_session = GlobalSession.new(directory, cookie, cached_digest)

          session_without_global_session[:_session_gbl_valid_sig] = @global_session.signature_digest
          return true
        rescue Exception => e
          #silently recover from any error by initializing a new global session
          #and updating the session cookie
          @global_session = GlobalSession.new(directory)
          global_session_update_cookie

          #give the Rails app a chance to handle the exception
          #unless it's an ExpiredSession, which we handle transparently
          raise e
        end
      end

      # Before-filter to renew the global session if it will be expiring soon.
      #
      # === Return
      # true:: Always returns true
      def global_session_auto_renew
        #Auto-renew session if needed
        renew = Configuration['renew']
        if @global_session &&
           renew &&
           @global_session.directory.local_authority_name &&
           @global_session.expired_at < renew.to_i.minutes.from_now.utc
          @global_session.renew!
        end

        return true
      end

      # After-filter to write any pending changes to the global session cookie.
      #
      # === Return
      # true:: Always returns true
      def global_session_update_cookie
        name   = Configuration['cookie']['name']
        domain = Configuration['cookie']['domain'] || request.env['SERVER_NAME']

        begin
          if @global_session && @global_session.valid?
            value   = @global_session.to_s
            expires = Configuration['ephemeral'] ? nil : @global_session.expired_at

            unless (cookies[name] == value)
              #Update the cookie only if its value has changed
              cookies[name] = {:value => value, :domain=>domain, :expires=>expires}
            end
          else
            #No valid session? Write an empty cookie.
            cookies[name] = {:value=>nil, :domain=>domain, :expires=>Time.at(0)}
          end
        rescue Exception => e
          #silently recover from any error by wiping the cookie
          cookies[name] = {:value=>nil, :domain=>domain, :expires=>Time.at(0)}
          #give the Rails app a chance to handle the exception
          raise e
        end
      end

      # Override for the ActionController method of the same name that logs
      # information about the request. Our version logs the global session ID
      # instead of the local session ID.
      #
      # === Parameters
      # name(Type):: Description
      #
      # === Return
      # name(Type):: Description
      def log_processing
        if logger && logger.info?
          log_processing_for_request_id
          log_processing_for_parameters
        end
      end

      def log_processing_for_request_id # :nodoc:
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

      def log_processing_for_parameters # :nodoc:
        parameters = respond_to?(:filter_parameters) ? filter_parameters(params) : params.dup
        parameters = parameters.except!(:controller, :action, :format, :_method)

        logger.info "  Parameters: #{parameters.inspect}" unless parameters.empty?
      end

      private

      def global_session_create_directory # :nodoc:
        if (klass = Configuration['directory'])
          klass = klass.constantize
        else
          klass = Directory
        end

        return klass.new(File.join(RAILS_ROOT, 'config', 'authorities'))        
      end
    end
  end
end
