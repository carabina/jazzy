require 'optparse'
require 'pathname'

module Jazzy
  class Config
    attr_accessor :output, :xcodebuild_arguments, :author_name, :module_name
    attr_accessor :github_url, :github_file_prefix, :author_url, :dash_url
    attr_accessor :sourcekitten_sourcefile, :clean, :readme_path
    attr_accessor :docset_platform, :root_url, :version

    def initialize
      self.output = Pathname('docs')
      self.xcodebuild_arguments = []
      self.author_name = ''
      self.module_name = ''
      self.author_url = ''
      self.clean = false
      self.docset_platform = 'jazzy'
      self.version = '1.0'
    end

    # rubocop:disable Metrics/MethodLength
    def self.parse!
      config = new
      OptionParser.new do |opt|
        opt.banner = 'Usage: jazzy'
        opt.separator ''
        opt.separator 'Options'

        opt.on('-o', '--output FOLDER',
               'Folder to output the HTML docs to') do |output|
          config.output = Pathname(output)
        end

        opt.on('-c', '--[no-]clean',
               'Delete contents of output directory before running.',
               'WARNING: If --output is set to ~/Desktop, this will delete the \
                ~/Desktop directory.') do |clean|
          config.clean = clean
        end

        opt.on('-x', '--xcodebuild-arguments arg1,arg2,…argN', Array,
               'Arguments to forward to xcodebuild') do |args|
          config.xcodebuild_arguments = args
        end

        opt.on('-a', '--author AUTHOR_NAME',
               'Name of author to attribute in docs (i.e. Realm)') do |a|
          config.author_name = a
        end

        opt.on('-u', '--author_url URL',
               'Author URL of this project (i.e. http://realm.io)') do |u|
          config.author_url = u
        end

        opt.on('-m', '--module MODULE_NAME',
               'Name of module being documented. (i.e. RealmSwift)') do |m|
          config.module_name = m
        end

        opt.on('-d', '--dash_url URL',
               'URL to install docs in Dash (i.e. dash-feed://...') do |d|
          config.dash_url = d
        end

        opt.on('-g', '--github_url URL',
               'GitHub URL of this project (i.e. \
                https://github.com/realm/realm-cocoa)') do |g|
          config.github_url = g
        end

        opt.on('--github-file-prefix PREFIX',
               'GitHub URL file prefix of this project (i.e. \
                https://github.com/realm/realm-cocoa/tree/v0.87.1)') do |g|
          config.github_file_prefix = g
        end

        opt.on('-s', '--sourcekitten-sourcefile FILEPATH',
               'XML doc file generated from sourcekitten to parse') do |s|
          config.sourcekitten_sourcefile = Pathname(s)
        end

        opt.on('-r', '--root-url URL',
               'Absolute URL root where these docs will be stored') do |r|
          config.root_url = r
          if !config.dash_url && config.root_url
            config.dash_url = "#{r}/docsets/#{config.module_name}.xml"
          end
        end

        opt.on('--module-version VERSION',
               'module version. will be used when generating docset') do |mv|
          config.version = mv
        end

        opt.on('-v', '--version', 'Print version number') do
          puts 'jazzy version: ' + Jazzy::VERSION
          exit
        end

        opt.on('-h', '--help', 'Print this help message') do
          puts opt
          exit
        end
      end.parse!

      config
    end

    #-------------------------------------------------------------------------#

    # @!group Singleton

    # @return [Config] the current config instance creating one if needed.
    #
    def self.instance
      @instance ||= new
    end

    # Sets the current config instance. If set to nil the config will be
    # recreated when needed.
    #
    # @param  [Config, Nil] the instance.
    #
    # @return [void]
    #
    class << self
      attr_writer :instance
    end

    # Provides support for accessing the configuration instance in other
    # scopes.
    #
    module Mixin
      def config
        Config.instance
      end
    end
  end
end
