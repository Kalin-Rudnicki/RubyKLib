
require_relative '../validation/ArgumentChecking'

module KLib
	
	module Env
		
		@env = {}
		
		def self.var(name, var_name, *accepted_values, default: accepted_values.first, missing: :default, &block)
			ArgumentChecking.type_check(name, :name, Symbol)
			ArgumentChecking.type_check(var_name, :var_name, Symbol)
			ArgumentChecking.enum_check(missing, :missing, :ignore, :default, :warn, :error)
			
			if ENV.key?(var_name.to_s)
				val = ENV[var_name.to_s]
				if val.downcase == "true"
					val = true
				elsif val.downcase == "false"
					val = false
				elsif /^-?\d+$/.match?(val)
					val = val.to_i
				elsif /^-(\d+\.\d+|\.\d+)$/.match?(val)
					val = val.to_f
				else
					accepted_values.each do |a_val|
						if a_val.is_a?(Symbol) && val.downcase == a_val.to_s.downcase
							val = a_val
							break
						end
					end
				end
				if accepted_values.any?
					unless accepted_values.include?(val)
						$stderr.puts("Invalid env-var value for '#{var_name}' (#{val}), expected: #{accepted_values.inspect}")
						exit(1)
					end
				end
				unless block.nil? || (res = block.(val)) == true
					if res.is_a?(String)
						$stderr.puts("Invalid env-var value for '#{var_name}': #{res}")
					else
						$stderr.puts("Invalid env-var value for '#{var_name}'")
					end
					exit(1)
				end
				@env[name] = val
			else
				case missing
					when :ignore
					when :default
						@env[name] = default
					when :warn
						$stderr.puts("No env-var value for '#{var_name}', using: #{default}")
						@env[name] = default
					when :error
						$stderr.puts("No env-var value for '#{var_name}'")
						exit(1)
					else
						raise "What is going on?"
				end
			end
			
			nil
		end
		
		def self.key?(key)
			@env.key?(key)
		end
		
		def self.[] (key)
			@env[key]
		end
		
		# =====| Variables |=====
		# TODO : Add more vars
		
	end
	
end
