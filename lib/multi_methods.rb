module MultiMethods
    def self.included base
      base.extend( ClassMethods )
      base.class_eval { include InstanceMethods }
    end

    module ClassMethods

      def create_method( name, &block ) 
        self.send( :define_method, name, block )
      end

      def defmulti method_name, default_dispatch_fn = nil
        self.instance_variable_set( "@" + method_name.to_s, [] )

        create_method( method_name ) do |*args|
          dispatch_table = self.class.instance_variable_get( "@" + method_name.to_s )

          destination_fn = nil
          default_fn = nil
          default_dispatch_result = default_dispatch_fn.call(args)  if default_dispatch_fn 
          dispatch_table.each do |m|
            predicate = if m.keys.first.respond_to? :call
                          raise "Dispatch method already defined by defmulti" if default_dispatch_fn
                          m.keys.first
                        elsif  m.keys.first == :default
                          default_fn = m.values.first
                          lambda { |args| false }
                        else
                          lambda { |args| return default_dispatch_result == m.keys.first }
                        end

            destination_fn = m.values.first if predicate.call(args)
          end

          destination_fn ||= default_fn
          raise "No matching dispatcher function found" unless destination_fn 
          
          if destination_fn.is_a? UnboundMethod
            destination_fn.bind(self).call(args)
          else
            destination_fn.call(args)
          end

        end
      end
    
      def defmethod method_name, dispatch_value, default_dispatch_fn
        multi_method = self.instance_variable_get( "@" + method_name.to_s)  
        raise "MultiMethod #{method_name} not defined" unless  multi_method
        multi_method << {  dispatch_value => default_dispatch_fn } 
      end
    end #ClassMethods


    module InstanceMethods

      def defmulti_local &block
        dispatch_return = instance_eval &block 

        #clean up after evaling block
        instance_eval do 
          method_name = instance_variable_get( :@added_multi_method )
          self.class.send(:undef_method, method_name)
          self.class.send(:remove_instance_variable,  ('@' + method_name.to_s).to_sym )
          self.send( :remove_instance_variable, :@added_multi_method )
        end

        dispatch_return 
      end

      def defmulti method_name, default_dispatch_fn = nil
        instance_variable_set( :@added_multi_method, method_name )
        self.class.defmulti method_name, default_dispatch_fn
      end

      def defmethod method_name, dispatch_value, default_dispatch_fn
        self.class.defmethod method_name, dispatch_value, default_dispatch_fn
      end
    end #InstanceMethods
end

Object.send( :include, MultiMethods )
