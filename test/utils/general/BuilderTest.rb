
require_relative '../../../src/utils/general/Builder'

module Tmp
end

KLib::Builders::Builder.new(:spec) do |spec|
	
	spec.lexer(path: String) do |lexer|
		
		lexer.dfa(name: Symbol) do |dfa|
			
			dfa.state(num: Integer) do |state|
				
				state.transition(to: Integer, :"*with" => String).settings do |settings|
					settings.many
					settings.met(:on)
				end
				
				state.action(line: Integer, code: String).met(:set_action)
				
			end.hash(:num)
			
		end.hash(:name)
		
	end
	
	spec.grammar(path: String) do |grammar|
		
		grammar.productions do |productions|
			
			productions.production(idx: Integer) do |production|
				production.element(type: [Symbol, String], ignore: Boolean)
			end.many
			
		end
		
		grammar.states do |states|
			
			states.take_state(id: Integer) do |state|
				state.rescue(to: Symbol)
				state.transition(sym: Symbol, to: Integer).many.met(:on)
			end.settings do |settings|
				settings.many(:@states)
			end
			
			states.return_state(id: Integer) do |state|
				state.rescue(to: Symbol)
				state.return(nt: Symbol, idx: Integer)
			end.many(:@states)
			
		end
		
	end
	
end.__build(Tmp)

spec =
Dir.chdir(File.dirname(__FILE__)) do
	Tmp::Spec.parse_file("BuilderTest_TestFile.ssf")
end

spec.lexer.dfas.each_pair do |name, dfa|
	puts("name: #{name}, dfa: #{dfa.class}")
end
