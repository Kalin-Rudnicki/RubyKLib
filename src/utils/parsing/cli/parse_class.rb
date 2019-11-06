
require_relative 'spec_generator'

module KLib
	
	module CLI
		
		class UnimplementedMethodError < StandardError
			def initialize(method_name)
				super("You need to implement method '#{method_name}'")
			end
		end
		
		class ParseClass
			
			# Called very simply as ChildClass.new(ARGV)
			def initialize(argv)
			
			end
			
			# Meant to be overriden in child class
			# Called after all instance variables have been set
			def execute
				raise UnimplementedMethodError.new(:execute)
			end
			
			# Called in order to specify arguments
			def self.spec(*args, **hash_args, &block)
				spec_gen = SpecGenerator.new(*args, **hash_args, &block)
				
				nil
			end
		
		end
		
	end
	
end
