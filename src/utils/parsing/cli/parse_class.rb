
require_relative 'spec_generator'
require_relative 'spec_stubs'
require_relative '../../validation/ArgumentChecking'

module KLib
	
	module CLI
		
		SHORT_REGEX_BOOL = /^[A-Za-z]_[A-Za-z]$/
		SHORT_REGEX_OTHER = /^[A-Za-z]$/
		
		LOWER_REGEX = /^[a-z][a-z]*(_([a-z]+|[0-9]+))*$/
		UPPER_REGEX = /^[A-Z][a-z]*([A-Z][a-z]*|[0-9]+)*$/
		
		class ParseClass
			
			# Called very simply as ChildClass.new(ARGV)
			def initialize(argv)
				instance = parse(argv)
				# instance.execute
				nil
			end
			class << self
				alias :parse :new
			end
			
			# Called in order to specify arguments
			def self.spec(*args, **hash_args, &block)
				spec_gen = SpecGenerator.new(self, *args, **hash_args, &block)
				# TODO : Save necessary data for the spec into instance variables of the Class
				# Specs and their data
				# SubSpecs
				# Help messages
				nil
			end
			
			# TODO : help/help_extra/show_args might be improperly located
			
			private
			
				def parse(argv)
					# TODO : The whole thing
					
					nil
				end
		
		end
		
	end
	
end
