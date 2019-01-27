
module KLib

	module RemoteShell
		
		module Codes
			
			READ =   0x000
			WRITE =  0x001
			
			PRINT =  0x000
			PUTS =   0x002
			
			NON_HIDDEN =  0x000
			HIDDEN =      0x004
			
			SINGLE =  0x000
			MULTI =   0x008
			
			NO_CONFIRM =  0x000
			CONFIRM =     0x010
			
			NO_ENCRYPT =  0x000
			ENCRYPT =     0x020
			
			def self.encode(*codes)
				code = 0
				codes.each { |c| code |= c }
				code
			end
			
			def self.decode(code)
				if (code & WRITE) > 0
					{
						:mode => :write,
						:message_mode => (code & PUTS) != 0 ? :puts : :print,
					}
				else
					{
						:mode => :read,
						:message_mode => (code & PUTS) != 0 ? :puts : :print,
						:hidden => (code & HIDDEN) != 0,
						:multi => (code & MULTI) != 0,
						:confirm => (code & CONFIRM) != 0,
						:encrypt => (code & ENCRYPT) != 0
					}
				end
			end
			
		end
		
	end

end
