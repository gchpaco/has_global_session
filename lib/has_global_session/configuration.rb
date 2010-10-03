module HasGlobalSession
  # Central point of access for HasGlobalSession configuration information. This is
  # mostly a very thin wrapper around the serialized hash written to the YAML config
  # file.
  #
  # The configuration is stored as a set of nested hashes and accessed by the code
  # using hash lookup; for example, we might ask for +Configuration['cookie']['domain']+
  # if we wanted to know which domain the cookie should be set for.
  #
  # The following settings are supported:
  # * attributes
  #    * signed
  #    * insecure
  # * integrated
  # * ephemeral
  # * timeout
  # * renew
  # * authority
  # * trust
  # * directory
  # * cookie
  #     * name
  #     * domain
  #
  # === Config Environments
  # The operational environment of has_global_session defines which section
  # of the configuration file it gets its settings from. When used with
  # a web app, the environment should be set to the same environment as
  # the web app. (If using Rails integration, this happens for you
  # automatically.)
  #
  # === Environment-Specific Settings
  # The top level of keys in the configuration hash are special; they provide different
  # sections of settings that apply in different environments. For instance, a Rails
  # application might have one set of settings that apply in the development environment;
  # these would appear under +Configuration['development']+. Another set of settings would
  # apply in the production environment and would appear under +Configuration['production']+.
  #
  # === Common Settings
  # In addition to having one section for each operating environment, the configuration
  # file can specify a 'common' section for settings that apply
  #
  # === Lookup Mechanism  
  # When the code asks for +Configuration['foo']+, we first check whether the current
  # environment's config section has a value for foo. If one is found, we return that.
  #
  # If no environment-specific setting is found, we check the 'common' section and return
  # the value found there.
  #
  # === Config File Location
  # The name and location of the config file depend on the Web framework with which
  # you are integrating; see HasGlobalSession::Rails for more information.
  #
  class Configuration
    # Create a new Configuration objectt
    #
    # === Parameters
    # config_File(String):: Absolute path to the configuration file
    # environment(String):: Config file section from which
    #
    # === Raise
    # MissingConfiguration:: if config file is missing or unreadable
    # TypeError:: if config file does not contain a YAML-serialized Hash
    def initialize(config_file, environment)
      raise MissingConfiguration, "Missing or unreadable configuration file" unless File.readable?(config_file)
      @config      = YAML.load(File.read(config_file))
      @environment = environment
      raise TypeError, "#{config_file} must contain a Hash!" unless Hash === @config
      validate
    end

    # Reader for configuration elements. The reader first checks
    # the current environment's settings section for the named
    # value; if not found, it checks the common settings section.
    #
    # === Parameters
    # key(String):: Name of configuration element to retrieve
    #
    # === Return
    # value(String):: the value of the configuration element
    def [](key)
      get(key, true)
    end

    def validate # :nodoc
      ['attributes/signed', 'integrated', 'cookie/name', 'timeout'].each do |path|
        elements = path.split '/'
        object = get(elements.shift, false)
        elements.each do |element|
          object = object[element] if object
          if object.nil?
            msg = "#{File.basename(config_file)} does not specify required element #{elements.map { |x| "['#{x}']"}.join('')}"
            raise MissingConfiguration, msg
          end
        end
      end
    end

    private

    def get(key, validated) # :nodoc
      if @config.has_key?(@environment) &&
         @config[@environment].has_key?(key)
        return @config[@environment][key]
      else
        @config['common'][key]
      end
    rescue NoMethodError
      raise MissingConfiguration, "Configuration key '#{key}' not found"
    end
  end  
end