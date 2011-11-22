module SampleModels
  mattr_reader :models
  @@models = Hash.new { |h, model_class| 
    h[model_class] = Model.new(model_class)
  }
  
  mattr_reader :samplers
  @@samplers = Hash.new { |h, model_class|
    h[model_class] = Sampler.new(model_class)
  }
  
  def self.configure(model_class, &block)
    samplers[model_class].configure(block)
  end
  
  def self.init
    Initializer.new.run
  end
  
  protected
  
  def self.included(mod)
    mod.extend ARClassMethods
    super
  end

  module ARClassMethods
    def create_sample(*args)
      ActiveSupport::Deprecation.warn("#{self.name}.create_sample is deprecated and will be removed in the next major version of SampleModels. Call #{self.name}.sample instead")
      sample(*args)
    end
    
    def sample(*args)
      SampleModels.samplers[self].sample(*args)
    end
  end
end

Dir.entries(File.dirname(__FILE__) + "/sample_models").each do |entry|
  if entry =~ /(.*)\.rb$/
    require "sample_models/#{$1}"
  end
end

SampleModels.init

