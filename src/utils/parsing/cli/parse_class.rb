
require_relative 'spec_generator'

module KLib
	
	module CLI
		
		LOWER_REGEX = /^[a-z][a-z]*(_([a-z]+|[0-9]+))*$/
		UPPER_REGEX = /^[A-Z][a-z]*([A-Z][a-z]*|[0-9]+)*$/
		
		class ParseClass
			
			# Called very simply as ChildClass.new(ARGV)
			def initialize(argv)
				parse(argv)
				execute # Dynamically defined by spec.action { }
				nil
			end
			
			# Called in order to specify arguments
			def self.spec(*args, **hash_args, &block)
				spec_gen = SpecGenerator.new(*args, **hash_args, &block)
				# TODO : Save necessary data for the spec into instance variables of the Class
				# Specs and their data
				# SubSpecs
				# Help messages
				nil
			end
			
			# @help and @help_extra generated in self.spec
			def help
				@help
			end
			def help_extra
				@help_extra
			end
			
			private
			
				def parse(argv)
					# TODO : The whole thing
					
					nil
				end
			
				def show_args
					# TODO : Go based on saved stuff, not just instance variables
					valid_vars = instance_variables - []
					max_len = valid_vars.max { |a, b| a.length <=> b.length }
					valid_vars.each do |var|
						puts("#{var.ljust(max_len)}: #{instance_variable_get(var).inspect}")
					end
				end
		
		end
		
	end
	
end
