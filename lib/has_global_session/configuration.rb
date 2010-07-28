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
  module Configuration
    # Reader for the environment module-attribute.
    #
    # === Return
    # env(String):: The current configuration environment
    def self.environment; @environment; end

    # Writer for the environment module-attribute.
    #
    # === Parameters
    # value(String):: Configuration environment from which settings should be read
    #
    # === Return
    # env(String):: The new configuration environment
    def self.environment=(value); @environment = value; end

    # Reader for the config_file module-attribute.
    #
    # === Return
    # file(String):: Absolute path to configuration file
    def self.config_file; @config_file; end

    # Writer for the config_file module-attribute.
    #
    # === Parameters
    # value(String):: Absolute path to configuration file
    #
    # === Return
    # env(String):: The new path to the configuration file
    def self.config_file=(value); @config_file= value; end

    # Reader for configuration elements. The reader first checks
    # the current environment's settings section for the named
    # value; if not found, it checks the common settings section.
    #
    # === Parameters
    # name(Type):: Description
    #
    # === Return
    # name(Type):: Description
    #
    # === Raise
    # MissingConfiguration:: if config file location is unset, environment is unset, or config file is missing
    # TypeError:: if config file does not contain a YAML-serialized Hash
    def self.[](key)
      get(key, true)
    end

    def self.validate # :nodoc
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

    def self.get(key, validated) # :nodoc
      unless @config
        raise MissingConfiguration, "config_file is nil; cannot read configuration" unless config_file
        raise MissingConfiguration, "environment is nil; must be specified" unless environment
        @config = YAML.load(File.read(config_file))
        raise TypeError, "#{config_file} must contain a Hash!" unless Hash === @config
        validate if validated
      end
      if @config.has_key?(environment) &&
         @config[environment].has_key?(key)
        return @config[environment][key]
      else
        @config['common'][key]
      end
    rescue NoMethodError
      raise MissingConfiguration, "Configuration key '#{key}' not found"
    end
  end  
end