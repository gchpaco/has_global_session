require File.expand_path(File.join(File.dirname(__FILE__), '..' , 'spec_helper'))

include HasGlobalSession

describe IntegratedSession do
  include SpecHelper

  context :[] do
    it 'should work'
  end

  context :[]= do
    it 'should work'
  end

  context :has_key? do
    it 'should work'
  end

  context :keys do
    it 'should work'
  end

  context :values do
    it 'should work'
  end

  context :each_pair do
    it 'should work'
  end

  context :method_missing do
    it 'should work'
  end
end