require_relative 'reference_collector'

module Reek
  module AST
    #
    # Extension modules providing utility methods to ASTNode objects, depending
    # on their type.
    #
    module SexpExtensions
      # Base module for utility methods for argument nodes.
      module ArgNodeBase
        def name
          children.first
        end

        # Other is a symbol?
        def ==(other)
          name == other
        end

        def marked_unused?
          plain_name.start_with?('_')
        end

        def plain_name
          name.to_s
        end

        def block?
          false
        end

        def optional_argument?
          false
        end

        def anonymous_splat?
          false
        end

        def components
          [self]
        end
      end

      # Utility methods for :arg nodes.
      module ArgNode
        include ArgNodeBase
      end

      # Utility methods for :kwarg nodes.
      module KwargNode
        include ArgNodeBase
      end

      # Utility methods for :optarg nodes.
      module OptargNode
        include ArgNodeBase

        def optional_argument?
          true
        end
      end

      # Utility methods for :kwoptarg nodes.
      module KwoptargNode
        include ArgNodeBase

        def optional_argument?
          true
        end
      end

      # Utility methods for :blockarg nodes.
      module BlockargNode
        include ArgNodeBase
        def block?
          true
        end
      end

      # Utility methods for :restarg nodes.
      module RestargNode
        include ArgNodeBase
        def anonymous_splat?
          !name
        end
      end

      # Utility methods for :kwrestarg nodes.
      module KwrestargNode
        include ArgNodeBase
        def anonymous_splat?
          !name
        end
      end

      # Utility methods for :shadowarg nodes.
      module ShadowargNode
        include ArgNodeBase
      end

      # Base module for utility methods for nodes that can contain argument
      # nodes nested through :mlhs nodes.
      module NestedAssignables
        def components
          children.flat_map(&:components)
        end
      end

      # Utility methods for :args nodes.
      module ArgsNode
        include NestedAssignables
      end

      # Utility methods for :mlhs nodes.
      module MlhsNode
        include NestedAssignables
      end

      # Base module for utility methods for :and and :or nodes.
      module LogicOperatorBase
        def condition() children.first end

        def body_nodes(type, ignoring = [])
          children[1].find_nodes type, ignoring
        end
      end

      # Utility methods for :and nodes.
      module AndNode
        include LogicOperatorBase
      end

      # Utility methods for :or nodes.
      module OrNode
        include LogicOperatorBase
      end

      # Utility methods for :attrasgn nodes.
      module AttrasgnNode
        def args() children[2] end
      end

      # Utility methods for :case nodes.
      module CaseNode
        def condition() children.first end

        def body_nodes(type, ignoring = [])
          children[1..-1].compact.flat_map { |child| child.find_nodes(type, ignoring) }
        end

        def else_body
          children.last
        end
      end

      # Utility methods for :when nodes.
      module WhenNode
        def condition_list
          children[0..-2]
        end

        def body
          children.last
        end
      end

      # Utility methods for :send nodes.
      module SendNode
        def receiver; children.first; end
        def method_name() children[1]; end
        def args() children[2..-1] end

        def participants
          ([receiver] + args).compact
        end

        def arg_names
          args.map { |arg| arg.children.first }
        end

        def module_creation_call?
          object_creation_call? && module_creation_receiver?
        end

        def module_creation_receiver?
          receiver && [:Class, :Struct].include?(receiver.simple_name)
        end

        def object_creation_call?
          method_name == :new
        end

        def visibility_modifier?
          VISIBILITY_MODIFIERS.include?(method_name)
        end

        def attribute_writer?
          ATTR_DEFN_METHODS.include?(method_name) ||
            attr_with_writable_flag?
        end

        # Handles the case where we create an attribute writer via:
        # attr :foo, true
        def attr_with_writable_flag?
          method_name == :attr && args.any? && args.last.type == :true
        end

        VISIBILITY_MODIFIERS = [:private, :public, :protected, :module_function]
        ATTR_DEFN_METHODS = [:attr_writer, :attr_accessor]
      end

      Op_AsgnNode = SendNode

      # Base module for utility methods for nodes representing variables.
      module VariableBase
        def name() children.first end
      end

      # Utility methods for :cvar nodes.
      module CvarNode
        include VariableBase
      end

      CvasgnNode = CvarNode
      CvdeclNode = CvarNode

      # Utility methods for :ivar nodes.
      module IvarNode
        include VariableBase
      end

      # Utility methods for :ivasgn nodes.
      module IvasgnNode
        include VariableBase
      end

      # Utility methods for :lvar nodes.
      module LvarNode
        include VariableBase

        alias_method :simple_name, :name
        alias_method :var_name,    :name
      end

      LvasgnNode = LvarNode

      # Base module for utility methods for :def and :defs nodes.
      module MethodNodeBase
        def arguments
          parameters.reject(&:block?)
        end

        def arg_names
          arguments.map(&:name)
        end

        def parameters
          argslist.components
        end

        def parameter_names
          parameters.map(&:name)
        end

        def name_without_bang
          name.to_s.chop
        end

        def ends_with_bang?
          name[-1] == '!'
        end

        def body_nodes(types, ignoring = [])
          if body
            body.find_nodes(types, ignoring)
          else
            []
          end
        end
      end

      # Checking if a method is a singleton method.
      module SingletonMethod
        def singleton_method?
          singleton_method_via_class_self_notation?
        end

        # Ruby allows us to make a method a singleton_method using the
        # class << self syntax.
        #
        # To check for this we check if the parent node is of type :sclass.
        #
        # @return [Boolean]
        def singleton_method_via_class_self_notation?
          return unless parent
          parent.type == :sclass
        end
      end

      # Utility methods for :def nodes.
      module DefNode
        def name() children.first end
        def argslist() children[1] end

        def body
          children[2]
        end

        def full_name(outer)
          prefix = outer == '' ? '' : "#{outer}#"
          "#{prefix}#{name}"
        end

        def depends_on_instance?
          ReferenceCollector.new(self).num_refs_to_self > 0
        end

        include MethodNodeBase
        include SingletonMethod
      end

      # Utility methods for :defs nodes.
      module DefsNode
        def receiver() children.first end
        def name() children[1] end
        def argslist() children[2] end

        def body
          children[3]
        end

        include MethodNodeBase

        def full_name(outer)
          prefix = outer == '' ? '' : "#{outer}#"
          "#{prefix}#{SexpFormatter.format(receiver)}.#{name}"
        end

        def depends_on_instance?
          false
        end
      end

      # Utility methods for :if nodes.
      module IfNode
        def condition() children.first end

        def body_nodes(type, ignoring = [])
          children[1..-1].compact.flat_map { |child| child.find_nodes(type, ignoring) }
        end
      end

      # Utility methods for :block nodes.
      module BlockNode
        def call() children.first end
        def args() children[1] end
        def block() children[2] end
        def parameters() children[1] || [] end

        def parameter_names
          parameters.children
        end

        def simple_name
          :block
        end

        def without_block_arguments?
          args.components.empty?
        end
      end

      # Utility methods for :lit nodes.
      module LitNode
        def value() children.first end
      end

      # Utility methods for :const nodes.
      module ConstNode
        def simple_name
          children.last
        end
      end

      # Base module for utility methods for module nodes.
      module ModuleNodeBase
        # The full name of the module or class, including the name of any
        # module or class it is nested inside of.
        #
        # For example, given code like this:
        #
        #   module Foo
        #     class Bar::Baz
        #     end
        #   end
        #
        # The full name for the inner class will be 'Foo::Bar::Baz'. To return
        # the correct name, the name of the outer context has to be passed into this method.
        #
        # @param outer [String] full name of the wrapping module or class
        # @return the module's full name
        def full_name(outer)
          prefix = outer == '' ? '' : "#{outer}::"
          "#{prefix}#{name}"
        end

        # The final section of the module or class name. For example, for a
        # module with name 'Foo::Bar' this will return 'Bar'; for a module with
        # name 'Foo' this will return 'Foo'.
        #
        # @return [String] the final section of the name
        def simple_name
          name.split('::').last
        end
      end

      # Utility methods for :module nodes.
      module ModuleNode
        include ModuleNodeBase

        # @return [String] name as given in the module statement
        def name
          SexpFormatter.format(children.first)
        end
      end

      # Utility methods for :class nodes.
      module ClassNode
        include ModuleNode
        def superclass() children[1] end
      end

      # Utility methods for :casgn nodes.
      module CasgnNode
        include ModuleNodeBase

        def defines_module?
          return false unless value
          call = case value.type
                 when :block
                   value.call
                 when :send
                   value
                 end
          call && call.module_creation_call?
        end

        def name
          SexpFormatter.format(children[1])
        end

        # there are two valid forms of the casgn sexp
        # (casgn <namespace> <name> <value>) and
        # (casgn <namespace> <name>) used in or-asgn and mlhs
        #
        # source = "class Hi; THIS ||= 3; end"
        # (class
        #   (const nil :Hi) nil
        #   (or-asgn
        #    (casgn nil :THIS)
        #    (int 3)))
        def value
          children[2]
        end
      end

      # Utility methods for :yield nodes.
      module YieldNode
        def args() children end

        def arg_names
          args.map { |arg| arg[1] }
        end
      end

      # Utility methods for :super nodes.
      module SuperNode
        def method_name
          :super
        end
      end

      ZsuperNode = SuperNode

      # Utility methods for :sym nodes.
      module SymNode
        def name
          children.first
        end

        def full_name(outer)
          prefix = outer == '' ? '' : "#{outer}#"
          "#{prefix}#{name}"
        end
      end
    end
  end
end
