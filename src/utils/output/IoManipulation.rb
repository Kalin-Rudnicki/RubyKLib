
Dir.chdir(File.dirname(__FILE__)) do
	require './../validation/HashNormalizer'
end

module KLib

	module IoManipulation
		
		class << self
		
			def snatch_io(hash_args = {}, &block)
				raise ArgumentError.new('You must supply a block to this method') unless block_given?
				hash_args = HashNormalizer.normalize(hash_args) do |norm|
					norm.replace_constants.boolean_check.default_value(true)
					norm.preserve_raised.boolean_check.default_value(false)
				end
				
				stdout = $stdout
				stderr = $stderr
				
				out_read, out_write = IO.pipe
				err_read, err_write = IO.pipe
				
				$stdout = out_write
				$stderr = err_write
				
				if hash_args[:replace_constants]
					Object.send(:remove_const, :STDOUT)
					Object.const_set(:STDOUT, out_write)
					Object.send(:remove_const, :STDERR)
					Object.const_set(:STDERR, err_write)
				end
				
				begin
					block.call
				rescue Exception => e
					error = e
				else
					error = nil
				ensure
					out_write.close
					err_write.close
					
					$stdout = stdout
					$stderr = stderr
					
					if hash_args[:replace_constants]
						Object.send(:remove_const, :STDOUT)
						Object.const_set(:STDOUT, stdout)
						Object.send(:remove_const, :STDERR)
						Object.const_set(:STDERR, stderr)
					end
				end
				
				raise error if !hash_args[:preserve_raised] && !error.nil?
				
				[out_read, err_read, error]
			end
		
		end
		
	end

end
