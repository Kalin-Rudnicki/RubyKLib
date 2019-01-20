
module KLib

	module IoManipulation
		
		class << self
		
			def snatch_io(&block)
				raise ArgumentError.new('You must supply a block to this method') unless block_given?
				
				stdout = $stdout
				stderr = $stderr
				
				out_read, out_write = IO.pipe
				err_read, err_write = IO.pipe
				
				$stdout = out_write
				$stderr = err_write
				
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
				end
				
				raise error unless error.nil?
				
				[out_read, err_read]
			end
		
		end
		
	end

end
