module HasGlobalSession
  class MissingConfiguration < Exception; end

  module Configuration
    mattr_accessor :config_file
    mattr_accessor :environment
    
    def self.[](key)
      unless @config
        raise MissingConfiguration, "config_file is nil; cannot read configuration" unless config_file
        raise MissingConfiguration, "environment is nil; must be specified" unless environment
        @config = YAML.load(File.read(config_file))
        validate
      end
      if @config.has_key?(environment) && @config[environment].has_key?(key)
        return @config[environment][key]
      else
        @config['common'][key]
      end
    end

    def self.validate
      ['attributes/signed', 'integrated', 'cookie/name', 'cookie/domain'].each do |path|
        elements = path.split '/'
        object = self[elements.shift]
        elements.each do |element|
          object = object[element]
          if object.nil?
            msg = "#{File.basename(config_file)} does not specify required element #{elements.map { |x| "['#{x}']"}.join('')}"
            raise MissingConfiguration, msg
          end
        end
      end
    end
  end  
end