# frozen_string_literal: true

require 'ox'

tags = %w[Media
  VideoMediaSource
  AudioSequenceSource
  VideoSequenceSource
  AudioClip
  VideoClip]

class Handler
  def self.parse(source)
    handler = new
    ::Ox.sax_parse(handler, source, smart: true)
  end

  def initialize
    @level = 0
  end

  def attr(name, value)
    name.to_s
  end

  def start_element(name)
    @level += 2
    puts "#{ " " * @level} > #{name}"
    name.to_s
  end

  def end_element(name)
    puts "#{ " " * @level} < #{name}"
    @level -= 2
    name.to_s
  end

  def text(str)
  end

  def error(message, line, column)
    puts([message, line, column])
    raise message
  end
end

# If this XML is parsed first, the second one works as well.
# Handler.parse(File.read("one.xml"))

Handler.parse(File.read('two.xml'))
