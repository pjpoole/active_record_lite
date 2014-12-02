require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    where_line = params.keys.map { |key| "#{key} = ?" }.join(" AND ")
    values = params.values

    results = DBConnection.execute(<<-SQL, *values)
      SELECT
        *
      FROM
        #{ table_name }
      WHERE
        #{ where_line }
    SQL

    return [] if results.nil?

    parse_all(results)
  end
end

class SQLObject
  extend Searchable
end
