
require_relative '../validation/ArgumentChecking'
require_relative '../validation/StringCasing'
require 'active_support/inflector'

module KLib
	
	module Builders
		
		class Class < BasicObject
			
			class << self
				attr_reader :hash_args, :rest, :vars, :mets
				
				def parse_file(path)
					eval(File.read(path), binding, path, 1)
				end
				
				def parse_string(str)
					eval(str)
				end
				
				def parse(*args, &block)
					new(nil, *args, &block)
				end
			end
			
			def initialize(parent_node, *args, &block)
				@parent_node = parent_node
				@__building = true
				
				klass = __call__(:class)
				if klass.rest
					if args.size < klass.hash_args.size - 1
						::Kernel.raise_not_me ::ArgumentError.new("wrong number of arguments (given #{args.size}, expected #{klass.hash_args.size - 1}+), args: [#{klass.hash_args.keys.join(', ')}]")
					end
					klass.hash_args.each_with_index do |a, i|
						k, v = *a
						if i == klass.hash_args.size - 1
							arg = args[i..-1]
							::KLib::RaiseNotMe.ignore_me do
								::KLib::ArgumentChecking.type_check_each(arg, :"#{k[1..-1]}", *v)
							end
							__call__(:instance_variable_set, :"@#{k[1..-1]}", arg)
						else
							arg = args[i]
							::KLib::RaiseNotMe.ignore_me do
								::KLib::ArgumentChecking.type_check(arg, k, *v)
							end
							__call__(:instance_variable_set, :"@#{k}", arg)
						end
					end
				else
					if args.size != klass.hash_args.size
						::Kernel.raise_not_me ::ArgumentError.new("wrong number of arguments (given #{args.size}, expected #{klass.hash_args.size}), args: [#{klass.hash_args.keys.join(', ')}]")
					end
					klass.hash_args.each_with_index do |a, i|
						k, v = *a
						arg = args[i]
						::KLib::RaiseNotMe.ignore_me do
							::KLib::ArgumentChecking.type_check(arg, k, *v)
						end
						__call__(:instance_variable_set, :"@#{k}", arg)
					end
				end
				
				klass.vars.each_pair do |var, type|
					case type
						when :arg, :rest_arg
						when :one
							self.instance_eval("#{var} = nil")
						when :many
							self.instance_eval("#{var} = []")
						when :hash
							self.instance_eval("#{var} = {}")
						else
							::Kernel.raise "What is going on?"
					end
				end
				
				block.(self) if block
				
				__call__(:remove_instance_variable, :@__building)
				
				nil
			end
			
			alias :__og_method_missing :method_missing
			def method_missing(sym, *args, &block)
				klass = __call__(:class)
				if __call__(:instance_variable_defined?, :@__building)
					if klass.mets.key?(sym)
						child = klass.mets[sym]
						child_res = child.__klass.new(self, *args, &block)
						# TODO : ?????
						case child.__settings.multi
							when :one
								#__call__(:instance_variable_set, child.__settings.var, child_res)
								::Kernel.eval("#{child.__settings.var} = child_res", ::Kernel.binding)
							when :many
								__call__(:instance_variable_get, child.__settings.var) << child_res
								# ::Kernel.eval("#{child.__settings.var} = child_res", ::Kernel.binding)
							when :hash
								__call__(:instance_variable_get, child.__settings.var)[child_res.send(child.__settings.hash_met)] = child_res
								# ::Kernel.eval("#{child.__settings.var} = child_res", ::Kernel.binding)
							else
								::Kernel.raise "What is going on?"
						end
					else
						__og_method_missing(sym, *args, &block)
					end
				else
					if sym.to_s.end_with?("=")
						var = :"@#{sym[0..-2]}"
						::Kernel.raise ::ArgumentError.new("wrong number of arguments (given #{args.size}, expected 1})") if args.size != 1
						__call__(:instance_variable_set, var, args[0])
					else
						var = :"@#{sym}"
						if (begin; __call__(:instance_variable_defined?, var); rescue ::NameError; false; end)
							::Kernel.raise ::ArgumentError.new("wrong number of arguments (given #{args.size}, expected 0})") if args.size != 0
							__call__(:instance_variable_get, var)
						else
							begin
								__call__(sym, *args)
							rescue ::NameError
								klass = self.class
								::Kernel.raise ::NameError.new("no method or instance variable '#{sym}' for #{klass.to_s.split('::')[-1]}, variables: #{__call__(:instance_variables).join(", ")} (#{klass})")
							end
						end
					end
				end
			end
			
			def __call__(met, *args, klass: ::Object, &block)
				::KLib::ArgumentChecking.type_check(met, :met, ::Symbol)
				::KLib::ArgumentChecking.type_check(klass, :klass, ::Module)
				klass.instance_method(met).bind(self).(*args, &block)
			end
			
			def inspect
				vars = (__call__(:instance_variables) - %i{@parent_node}).map do |var|
					res = __call__(:instance_variable_get, var)
					"#{var}=#{res.inspect}"
				end
				"#<#{self.class.to_s.split('::')[-1]}#{vars.any? ? "; " : ""}#{vars.join(", ")}>"
			end
			
		end
		
		class Builder < BasicObject
			
			def initialize(name, **hash_args, &block)
				::KLib::ArgumentChecking.type_check(name, :name, ::Symbol)
				::StringCasing.matches?(name.to_s, :snake)
				@hash_args = {}
				hash_args.each_pair do |k, v|
					::KLib::ArgumentChecking.type_check(v, :"hash_args[#{k}]", ::Class, ::Array)
					case v
						when ::Array
							::KLib::ArgumentChecking.type_check_each(v, :"hash_args[#{k}]", ::Class)
							@hash_args[k] = v
						when ::Class
							@hash_args[k] = [v]
						else
							::Kernel.raise "What is going on?"
					end
				end
				
				@name = name
				@class_name = name.to_s.to_camel(false).to_sym
				@children = {}
				@settings = Settings.new(self)
				
				block.(self) if block
				
				nil
			end
			
			def method_missing(name, **hash_args, &block)
				if @children.key?(name)
					::Kernel.raise "Already have child '#{name}'"
				else
					child = Builder.new(name, **hash_args, &block)
					@children[child.__name] = child
					child.__settings
				end
			end
			
			def __name
				@name
			end
			def __class_name
				@class_name
			end
			
			def __hash_args
				@hash_args
			end
			
			def __children
				@children
			end
			
			def __settings
				@settings
			end
			
			def __klass
				@klass
			end
			
			def __build(parent_mod = nil)
				::KLib::ArgumentChecking.type_check(parent_mod, :parent_mod, ::Module, ::NilClass)
				
				rest = false
				vars = {}
				mets = {}
				
				@hash_args.keys.each_with_index do |k, i|
					if k.to_s.start_with?("*")
						if i == @hash_args.size - 1
							rest = true
							vars[:"@#{k[1..-1]}"] = :rest_arg
						else
							::Kernel.raise "rest arg must be in last position '#{k}'"
						end
					else
						vars[:"@#{k}"] = :arg
					end
				end
				
				@children.each_value do |child|
					# vars
					::Kernel.raise "Overloaded variable #{child.__settings.var}" if vars.key?(child.__settings.var) && vars[child.__settings.var] != child.__settings.multi
					vars[child.__settings.var] = child.__settings.multi
					
					# mets
					::Kernel.raise "Can not use method parent_node" if child.__settings.met == :parent_node
					::Kernel.raise "Overloaded method #{child.__settings.met}" if mets.key?(child.__settings.met)
					mets[child.__settings.met] = child
				end
				
				@klass =
				if parent_mod
					parent_mod.const_set(@class_name, ::Class.new(Class))
				else
					::Class.new(Class)
				end
				
				@klass.instance_variable_set(:@hash_args, @hash_args)
				@klass.instance_variable_set(:@rest, rest)
				@klass.instance_variable_set(:@vars, vars)
				@klass.instance_variable_set(:@mets, mets)
				
				@children.each_value { |c| c.__build(@klass) }
				@klass
			end
		
			class Settings
				
				attr_reader :multi, :var, :met, :builder, :hash_met
				
				def initialize(builder)
					@builder = builder
					self.one
					self.met(@builder.__name)
					
					nil
				end
				
				# =====| multi |=====
				
				def one(var = :"@#{@builder.__name}")
					ArgumentChecking.type_check(var, :var, Symbol)
					@multi = :one
					@var = var
					self
				end
				
				def many(var = :"@#{@builder.__name.to_s.pluralize}")
					ArgumentChecking.type_check(var, :var, Symbol)
					@multi = :many
					@var = var
					self
				end
				
				def hash(met, var = :"@#{@builder.__name.to_s.pluralize}")
					ArgumentChecking.type_check(met, :met, Symbol)
					ArgumentChecking.type_check(var, :var, Symbol)
					@hash_met = met
					@multi = :hash
					@var = var
					self
				end
				
				# =====| misc |=====
				
				def settings(&block)
					raise ArgumentError.new("This method requires a block") unless block
					block.(self)
					self
				end
				
				def met(met = nil)
					if met.nil?
						@met
					else
						KLib::ArgumentChecking.type_check(met, :met, Symbol)
						@met = met
						self
					end
				end
				
			end
			
		end
		
	end
	
end
