# frozen_string_literal: true

# external gems
require "version_gem"
require "active_record"
require "active_support/core_ext/array/extract_options"

require "anonymous_active_record/version"
require "anonymous_active_record/generator"
require "anonymous_active_record/factory"

# Public API for AnonymousActiveRecord is:
#
#   AnonymousActiveRecord.generate -
#     defines a class, creates the table;
#     returns the class
#
#   Usage:
#
#     klass = AnonymousActiveRecord.generate(columns: ['name']) do
#               def flowery_name
#                 "🌸#{name}🌸"
#               end
#             end
#     instance = klass.new(name: 'Darla Charla')
#     instance.save!
#     instance.flowery_name # => "🌸Darla Charla🌸"
#
#   AnonymousActiveRecord.factory -
#     defines a class, creates the table, creates data;
#     returns inserted records
#
#   Usage:
#
#     records = AnonymousActiveRecord.factory(source_data: [{name: 'Bob McGurdy'}], columns: ['name']) do
#                 def flowery_name
#                   "🌸#{name}🌸"
#                 end
#               end
#     records.first.flowery_name # => "🌸Bob McGurdy🌸"
#
module AnonymousActiveRecord
  DEFAULT_CONNECTION_PARAMS = {
    adapter: "sqlite3",
    encoding: "utf8",
    database: ":memory:",
  }.freeze
  DEFAULT_PARENT_KLASS = "ActiveRecord::Base"

  # Defines a pseudo anonymous class in a particular namespace of your choosing.
  def generate(table_name: nil, klass_namespaces: [], klass_basename: nil, columns: [], indexes: [], timestamps: true, parent_klass: DEFAULT_PARENT_KLASS, connection_params: DEFAULT_CONNECTION_PARAMS, &block)
    gen = AnonymousActiveRecord::Generator.new(table_name, klass_namespaces, klass_basename, parent_klass)
    klass = gen.generate(&block)
    connection_params = YAML.load_file(connection_params) if connection_params.is_a?(String)
    klass.establish_connection(connection_params.dup)
    klass.connection.create_table(gen.table_name) do |t|
      columns.each do |col|
        if col.is_a?(Hash)
          # :name and :type are required at minimum
          name = col.delete(:name)
          type = col.delete(:type)
          t.column(name, type, **col)
        elsif col.is_a?(Array)
          options = col.extract_options!
          if options.present?
            t.column(*col, **options)
          elsif col.length == 1
            t.column(col[0], :string)
          else
            t.column(col[0], col[-1] || :string)
          end
        else
          t.column(col, :string)
        end
      end
      indexes.each do |idx_options|
        if idx_options.is_a?(Hash)
          column_names = idx_options.delete(:columns)
          t.index(column_names, **idx_options)
        elsif idx_options.is_a?(Array)
          options = idx_options.extract_options!
          t.index(*idx_options, **options)
        else
          t.index(idx_options)
        end
      end
      t.timestamps if timestamps
    end
    klass
  end

  # Initializes instances of a pseudo anonymous class in a particular namespace of your choosing.
  def factory(source_data: [], table_name: nil, klass_namespaces: [], klass_basename: nil, columns: [], indexes: [], timestamps: true, parent_klass: DEFAULT_PARENT_KLASS, connection_params: DEFAULT_CONNECTION_PARAMS, &block)
    factory = _factory(
      source_data: source_data,
      table_name: table_name,
      klass_namespaces: klass_namespaces,
      klass_basename: klass_basename,
      columns: columns,
      indexes: indexes,
      timestamps: timestamps,
      parent_klass: parent_klass,
      connection_params: connection_params,
      &block
    )
    factory.run
  end

  # Initializes instances of a pseudo anonymous class in a particular namespace of your choosing.
  def factory!(source_data: [], table_name: nil, klass_namespaces: [], klass_basename: nil, columns: [], indexes: [], timestamps: true, parent_klass: DEFAULT_PARENT_KLASS, connection_params: DEFAULT_CONNECTION_PARAMS, &block)
    factory = _factory(
      source_data: source_data,
      table_name: table_name,
      klass_namespaces: klass_namespaces,
      klass_basename: klass_basename,
      columns: columns,
      indexes: indexes,
      timestamps: timestamps,
      parent_klass: parent_klass,
      connection_params: connection_params,
      &block
    )
    factory.run!
  end

  private

  def _factory(source_data: [], table_name: nil, klass_namespaces: [], klass_basename: nil, columns: [], indexes: [], timestamps: true, parent_klass: DEFAULT_PARENT_KLASS, connection_params: DEFAULT_CONNECTION_PARAMS, &block)
    klass = generate(
      table_name: table_name,
      klass_namespaces: klass_namespaces,
      klass_basename: klass_basename,
      columns: columns,
      timestamps: timestamps,
      parent_klass: parent_klass,
      indexes: indexes,
      connection_params: connection_params,
      &block
    )
    AnonymousActiveRecord::Factory.new(source_data, klass)
  end

  module_function :generate, :factory, :factory!, :_factory
end

AnonymousActiveRecord::Version.class_eval do
  extend VersionGem::Basic
end
