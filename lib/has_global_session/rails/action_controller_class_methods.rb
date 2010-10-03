module HasGlobalSession
  module Rails
    # Module that is mixed into ActionController's eigenclass; provides access to shared
    # app-wide data such as the configuration object.
    module ActionControllerClassMethods
      def global_session_config
        unless @global_session_config
          config_file = File.join(RAILS_ROOT, 'config', 'global_session.yml')
          @global_session_config = HasGlobalSession::Configuration.new(config_file, RAILS_ENV)
          @global_session_config.config_file = config_file
        end

        return @global_session_config
      end

      def global_session_config=(config)
        @global_session_config = config
      end

      def has_global_session
        include HasGlobalSession::Rails::ActionControllerInstanceMethods
      end
    end
  end
end