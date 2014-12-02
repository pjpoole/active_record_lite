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
        #{eval(self.name).table_name}
      WHERE
        #{where_line}
    SQL

    return [] if results.nil?

    eval(self.name).parse_all(results)
  end
end

class SQLObject
  extend Searchable
end
