
Dir.chdir(File.dirname(__FILE__)) do
	require './../validation/ArgumentChecking'
end

module KLib

	module IoManipulation
		
		class << self
		
			def snatch_io(grab_constants = true, &block)
				raise ArgumentError.new('You must supply a block to this method') unless block_given?
				ArgumentChecking.boolean_check(grab_constants, 'grab_constants')
				
				stdout = $stdout
				stderr = $stderr
				
				out_read, out_write = IO.pipe
				err_read, err_write = IO.pipe
				
				$stdout = out_write
				$stderr = err_write
				
				if grab_constants
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
					
					if grab_constants
						Object.send(:remove_const, :STDOUT)
						Object.const_set(:STDOUT, stdout)
						Object.send(:remove_const, :STDERR)
						Object.const_set(:STDERR, stderr)
					end
				end
				
				raise error unless error.nil?
				
				[out_read, err_read]
			end
		
		end
		
	end

end
