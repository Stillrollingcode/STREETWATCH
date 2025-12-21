# frozen_string_literal: true

# Searchable concern provides database-agnostic search functionality
# Supports both PostgreSQL (ILIKE) and SQLite (LOWER + LIKE) automatically
module Searchable
  extend ActiveSupport::Concern

  class_methods do
    # Search across multiple fields with case-insensitive matching
    # Works with both PostgreSQL and SQLite
    #
    # @param query [String] The search term
    # @param fields [Array<Symbol>] The fields to search in
    # @return [ActiveRecord::Relation] The filtered records
    #
    # Example:
    #   User.search_by_fields('john', :username, :name, :bio)
    def search_by_fields(query, *fields)
      return all if query.blank?

      if postgresql?
        # PostgreSQL: Use ILIKE for case-insensitive search
        conditions = fields.map { |field| "#{table_name}.#{field} ILIKE :query" }.join(' OR ')
        where(conditions, query: "%#{query}%")
      else
        # SQLite: Use LOWER() with LIKE
        conditions = fields.map { |field| "LOWER(#{table_name}.#{field}) LIKE LOWER(:query)" }.join(' OR ')
        where(conditions, query: "%#{query}%")
      end
    end

    # Advanced search with custom SQL conditions
    # Accepts raw SQL that will be adapted for PostgreSQL or SQLite
    #
    # @param query [String] The search term
    # @param postgresql_sql [String] SQL conditions for PostgreSQL (using ILIKE)
    # @param sqlite_sql [String] SQL conditions for SQLite (using LOWER/LIKE)
    # @return [ActiveRecord::Relation] The filtered records
    #
    # Example:
    #   Film.search_with_sql(query,
    #     "films.title ILIKE :q OR EXISTS (...)",
    #     "LOWER(films.title) LIKE :q OR EXISTS (...)")
    def search_with_sql(query, postgresql_sql, sqlite_sql)
      return all if query.blank?

      if postgresql?
        where(postgresql_sql, q: "%#{query}%")
      else
        where(sqlite_sql, q: "%#{query.downcase}%")
      end
    end

    private

    def postgresql?
      ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql'
    end
  end
end
