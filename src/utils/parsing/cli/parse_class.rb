
require_relative 'spec_generator'

module KLib
	
	module CLI
		
		LOWER_REGEX = /^[a-z][a-z]*(_([a-z]+|[0-9]+))*$/
		UPPER_REGEX = /^[A-Z][a-z]*([A-Z][a-z]*|[0-9]+)*$/
		
		class UnimplementedMethodError < StandardError
			def initialize(method_name)
				super("You need to implement method '#{method_name}'")
			end
		end
		
		class ParseClass
			
			# Called very simply as ChildClass.new(ARGV)
			def initialize(argv)
				parse(argv)
				execute
				nil
			end
			
			# Meant to be overriden in child class
			# Called after all instance variables have been set
			def execute
				raise UnimplementedMethodError.new(:execute)
			end
			
			# Called in order to specify arguments
			def self.spec(*args, **hash_args, &block)
				spec_gen = SpecGenerator.new(*args, **hash_args, &block)
				# TODO
				nil
			end
			
			def help
				
			end
			
			def help_extra
				
			end
			
			private
			
				def parse(argv)
					
				end
		
		end
		
	end
	
end
