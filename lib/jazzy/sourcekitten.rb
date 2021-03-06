require 'json'
require 'pathname'

require 'jazzy/config'
require 'jazzy/source_declaration'
require 'jazzy/source_mark'
require 'jazzy/xml_helper'
require 'jazzy/highlighter'

module Jazzy
  # This module interacts with the sourcekitten command-line executable
  module SourceKitten
    # Group root-level docs by type and add as children to a group doc element
    def self.group_docs(docs, type)
      group, docs = docs.partition { |doc| doc.type == type }
      docs << SourceDeclaration.new.tap do |sd|
        sd.type     = SourceDeclaration::Type.overview
        sd.name     = type.plural_name
        sd.abstract = "The following #{type.plural_name.downcase} are " \
                      'available globally.'
        sd.children = group
      end if group.count > 0
      docs
    end

    # Generate doc URL by prepending its parents URLs
    # @return [Hash] input docs with URLs
    def self.make_doc_urls(docs, parents)
      docs.each do |doc|
        if doc.children.count > 0
          # Create HTML page for this doc if it has children
          parents_slash = parents.count > 0 ? '/' : ''
          doc.url = parents.join('/') + parents_slash + doc.name + '.html'
          doc.children = make_doc_urls(doc.children, parents + [doc.name])
        else
          # Don't create HTML page for this doc if it doesn't have children
          # Instead, make its link a hash-link on its parent's page
          doc.url = parents.join('/') + '.html#/' + doc.usr
        end
      end
    end

    # Run sourcekitten with given arguments and return STDOUT
    def self.run_sourcekitten(arguments)
      bin_path = Pathname(__FILE__).parent + '../../bin'
      `#{bin_path}/sourcekitten #{(arguments).join(' ')}`
    end

    def self.make_default_doc_info(declaration)
      # @todo: Fix these
      declaration.line = 0
      declaration.column = 0
      declaration.abstract = 'Undocumented'
      declaration.parameters = []
      declaration.children = []
    end

    def self.make_doc_info(doc, declaration)
      xml_key = 'key.doc.full_as_xml'
      return make_default_doc_info(declaration) unless doc[xml_key]

      xml = Nokogiri::XML(doc[xml_key]).root
      declaration.line = XMLHelper.attribute(xml, 'line').to_i
      declaration.column = XMLHelper.attribute(xml, 'column').to_i
      decl = XMLHelper.xpath(xml, 'Declaration')
      declaration.declaration = Highlighter.highlight(decl, 'swift')
      declaration.abstract = XMLHelper.xpath(xml, 'Abstract')
      declaration.discussion = XMLHelper.xpath(xml, 'Discussion')
      declaration.return = XMLHelper.xpath(xml, 'ResultDiscussion')

      declaration.parameters = []
      xml.xpath('Parameters/Parameter').each do |parameter_el|
        declaration.parameters << {
          name: XMLHelper.xpath(parameter_el, 'Name'),
          discussion: Jazzy.markdown.render(
              XMLHelper.xpath(parameter_el, 'Discussion'),
            ),
        }
      end
    end

    def self.make_substructure(doc, declaration)
      if doc['key.substructure']
        declaration.children = make_source_declarations(
          doc['key.substructure'],
        )
      else
        declaration.children = []
      end
    end

    # rubocop:disable Metrics/MethodLength
    def self.make_source_declarations(docs)
      declarations = []
      current_mark = SourceMark.new
      docs.each do |doc|
        if doc.key?('key.diagnostic_stage')
          declarations += make_source_declarations(doc['key.substructure'])
          next
        end
        declaration = SourceDeclaration.new
        declaration.type = SourceDeclaration::Type.new(doc['key.kind'])
        if declaration.type.mark? && doc['key.name'].start_with?('MARK: ')
          current_mark = SourceMark.new(doc['key.name'])
        end
        next unless declaration.type.declaration?

        unless declaration.type.name
          raise 'Please file an issue on ' \
          'https://github.com/realm/jazzy/issues about adding support for ' \
          "`#{declaration.type.kind}`."
        end

        declaration.file = doc['key.filepath']
        declaration.usr  = doc['key.usr']
        declaration.name = doc['key.name']
        declaration.mark = current_mark

        make_doc_info(doc, declaration)
        make_substructure(doc, declaration)
        declarations << declaration
      end
      declarations
    end
    # rubocop:enable Metrics/MethodLength

    def self.doc_coverage(sourcekitten_json)
      documented = sourcekitten_json
                    .map { |el| el['key.doc.documented'] }
                    .inject(:+)
      undocumented = sourcekitten_json
                      .map { |el| el['key.doc.undocumented'] }
                      .inject(:+)
      return 0 if documented == 0 && undocumented == 0
      (100 * documented) / (undocumented + documented)
    end

    # Parse sourcekitten STDOUT output as JSON
    # @return [Hash] structured docs
    def self.parse(sourcekitten_output)
      sourcekitten_json = JSON.parse(sourcekitten_output)
      docs = make_source_declarations(sourcekitten_json)
      SourceDeclaration::Type.all.each do |type|
        docs = group_docs(docs, type)
      end
      [make_doc_urls(docs, []), doc_coverage(sourcekitten_json)]
    end
  end
end
