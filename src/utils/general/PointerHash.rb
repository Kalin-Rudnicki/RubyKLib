
require_relative 'Pointer'
require_relative '../validation/ArgumentChecking'

module KLib
	
	class PointerHash
		
		def initialize(hash = {})
			KLib::ArgumentChecking.type_check(hash, :hash, Hash, PointerHash)
			
			@hash = {}
			case hash
				when Hash
					hash.each_pair { |k, v| self[k] = v }
				when PointerHash
					hash.each_pair { |k, v| self[k] = v.val }
				else
					raise "What is going on?"
			end
			
			nil
		end
		
		# =====| Access |=====
		
		def key?(key)
			@hash.key?(key)
		end
		
		def [] (key, missing: :error)
			KLib::ArgumentChecking.enum_check(missing, :missing, %i{nil init error})
			if @hash.key?(key)
				@hash[key]
			else
				case missing
					when :nil
						nil
					when :init
						@hash[key] = Pointer.new
					when :error
						raise "Missing key: #{key.inspect}"
					else
						raise "What is going on?"
				end
			end
		end
		
		def []= (key, val)
			if @hash.key?(key)
				pointer = @hash[key]
				pointer.val = val
				pointer
			else
				self.set(key, val)
			end
		end
		
		def set(key, val = nil)
			@hash[key] = Pointer.new(val)
		end
		
		# =====| Parts |=====
		
		def keys
			@hash.keys
		end
		
		def values(dereference: true)
			if dereference
				@hash.values.map { |v| v.val }
			else
				@hash.values
			end
		end
		
		# =====| Each |=====
		
		def each_key(&block)
			raise "This method requires a block" unless block
			@hash.each_key(&block)
			self
		end
		
		def each_value(dereference: true, &block)
			raise "This method requires a block" unless block
			if dereference
				@hash.each_value { |v| block.(v.val) }
			else
				@hash.each_value(&block)
			end
			self
		end
		
		def each_pair(dereference: true, &block)
			raise "This method requires a block" unless block
			if dereference
				@hash.each_pair { |k, v| block.(k, v.val) }
			else
				@hash.each_pair { |k, v| block.(k, v) }
			end
			self
		end
		
		# =====| Transforms |=====
		
		def to_hash
			@hash.transform_values { |v| v.val }
		end
		alias :to_h :to_hash
		
		def transform_keys(&block)
			raise "This method requires a block" unless block
			PointerHash.new(@hash.transform_keys(&block))
		end
		def transform_keys!(&block)
			raise "This method requires a block" unless block
			@hash.transform_keys!(&block)
			self
		end
		
		def transform_values(dereference: true, &block)
			raise "This method requires a block" unless block
			KLib::ArgumentChecking.boolean_check(dereference, :dereference)
			if dereference
				PointerHash.new(@hash.transform_values { |v| block.(v.val) })
			else
				PointerHash.new(@hash.transform_values(&block))
			end
		end
		def transform_values!(dereference: true, &block)
			raise "This method requires a block" unless block
			if dereference
				@hash.each_value { |v| v.val = block.(v.val) }
			else
				@hash.each_value { |v| v.val = block.(v) }
			end
			self
		end
		
	end
	
end
