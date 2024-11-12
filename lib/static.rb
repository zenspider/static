require "path_expander"
require "sexp_processor"
require "ruby_parser"
require "graph"
require "ruby2ruby"

class Static < MethodBasedSexpProcessor
  VERSION = "1.0.0"

  attr_accessor :klasses, :r2r

  def self.run args = ARGV
    self.new.run args
  end

  def initialize
    super

    self.klasses = {}
    self.r2r     = Ruby2Ruby.new

    # standard ruby stuff -- cleans up layout a lot
    add_class "Object", nil
    wire %w[RuntimeError StandardError Exception Object]

    # fairly standard rails stuffs
    add_module "ActiveSupport::Concern"
    wire %w[ApplicationRecord ActiveRecord::Base Object]
    wire %w[ApplicationController ActionController::Base Object]
  end

  def run args
    expander = PathExpander.new args, "**/*.{rb,rake}"
    files = expander.process

    files.each do |file|
      ast = parse file
      next unless ast
      process ast
    end

    $stderr.puts "done"

    build_graph
  end

  def parse file
    parser = RubyParser.new

    $stderr.print "."

    ruby = file == '-' ? $stdin.read : File.binread(file)

    parser.reset
    parser.parse ruby, file
  rescue RubyParser::SyntaxError, Racc::ParseError, Encoding::CompatibilityError => e
    warn "Error parsing #{file}:"
    warn "#{e.inspect} at #{e.backtrace.first(5).join(', ')}"
  end

  def process_call exp
    return exp if class_stack.empty? # top-level calls are ignored

    _, _recv, msg, name, *rest = exp

    case msg
    when :include, :extend then
      name = sexp_to_name name
      klasses[klass_name] << [msg, name]
    when :belongs_to, :has_many, :has_one then
      name = sexp_to_name name
      klasses[klass_name] << [msg, name]
    else
      # skip
    end

    exp
  end

  def process_defn exp
    s() # ignore
  end

  alias process_defs process_defn

  def process_class exp
    super do
      duper = sexp_to_name process exp.shift

      klasses[klass_name] = [:class, klass_name, duper || "Object"]

      process_until_empty exp
    end
  end

  def process_module exp
    super do
      klasses[klass_name] = [:module, klass_name, nil]

      process_until_empty exp
    end
  end

  def add_class name, duper
    klasses[name] = [:class, name, duper]
  end

  def add_module name
    klasses[name] = [:module, name, nil]
  end

  def wire classes
    classes.each_cons(2) do |a,b|
      add_class a, b
    end
  end

  def sexp_to_name sexp
    r2r.process sexp if sexp
  end

  def build_graph
    items = self.klasses.values

    digraph do
      boxes
      rotate

      dir = Graph::Attribute.new "dir = %p" % ["back"]
      head = Graph::Attribute.new "headport = w"
      tail = Graph::Attribute.new "tailport = e"

      # graph_attribs << "ratio=0.33"
      # graph_attribs << "overlap=scalexy" # false, compress, ...

      items.each do |(type, name, sklass, *rest)|
        next if name.end_with? "::ClassMethods"
        next if name.end_with? "::InstanceMethods"

        n = node name

        case type
        when :class then
          if sklass then
            sklass.gsub!(" ", "\n") # structs can be loooong
            e = edge sklass, name
            head << e
            tail << e
            dir << e
          end
        when :module then
          blue << n
        end

        rest.each do |(msg, subname)|
          case msg
          when :include then
            e = edge name, subname
            orange << e
          when :extend then
            e = edge name, subname
            blue << e
          when :belongs_to, :has_one, :has_many then
            # e = edge name, subname
            # e.label msg
          else
            raise "NO: #{msg.inspect} #{subname.inspect}"
          end
        end
      end

      save "static", "pdf"
    end
  end
end
