/**
 * 
 */
package org.apidb.apicommon.model.report;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Collection;
import java.util.Map;

import javax.sql.DataSource;

import org.apache.log4j.Logger;
import org.gusdb.wdk.model.AttributeField;
import org.gusdb.wdk.model.ColumnAttributeField;
import org.gusdb.wdk.model.FieldScope;
import org.gusdb.wdk.model.LinkAttributeField;
import org.gusdb.wdk.model.PrimaryKeyAttributeField;
import org.gusdb.wdk.model.RecordClass;
import org.gusdb.wdk.model.TableField;
import org.gusdb.wdk.model.TextAttributeField;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.dbms.DBPlatform;
import org.gusdb.wdk.model.dbms.SqlUtils;
import org.gusdb.wdk.model.query.SqlQuery;
import org.gusdb.wsf.util.BaseCLI;

/**
 * @author xingao
 * 
 */
public class FullRecordCacheCreator extends BaseCLI {

    private static final String ARG_PROJECT_ID = "model";
    private static final String ARG_SQL_FILE = "sqlFile";
    private static final String ARG_RECORD = "record";
    private static final String ARG_TABLE_FIELD = "field";
    private static final String ARG_CACHE_TABLE = "cacheTable";

    private static final String COLUMN_FIELD_NAME = "field_name";
    private static final String COLUMN_FIELD_TITLE = "field_title";
    private static final String COLUMN_CONTENT = "content";
    private static final String COLUMN_ROW_COUNT = "row_count";

    private static final String FUNCTION_CHAR_CLOB_AGG = "apidb.char_clob_agg";
    private static final String FUNCTION_CLOB_CLOB_AGG = "apidb.clob_clob_agg";

    private static final Logger logger = Logger.getLogger(FullRecordCacheCreator.class);

    /**
     * @param args
     * @throws Exception
     */
    public static void main(String[] args) throws Exception {
        String cmdName = System.getProperty("cmdName");
        if (cmdName == null) cmdName = FullRecordCacheCreator.class.getName();
        FullRecordCacheCreator creator = new FullRecordCacheCreator(cmdName,
                "Create the Dump Table");
        try {
            creator.invoke(args);
        } finally {
            System.exit(0);
        }
    }

    private WdkModel wdkModel;
    private String cacheTable;

    /**
     * @param command
     * @param description
     */
    protected FullRecordCacheCreator(String command, String description) {
        super(command, description);
    }

    protected void declareOptions() {
        addSingleValueOption(ARG_PROJECT_ID, true, null, "The ProjectId, which"
                + " should match the directory name under $GUS_HOME, where "
                + "model-config.xml is stored.");

        addSingleValueOption(ARG_SQL_FILE, true, null, "The file that contains"
                + " a sql that returns the primary key columns of the records");

        addSingleValueOption(ARG_RECORD, true, null, "The full name of the "
                + "record class to be dumped.");

        addSingleValueOption(ARG_CACHE_TABLE, true, null, "The name of the "
                + "cache table where the cached results are stored.");

        addSingleValueOption(ARG_TABLE_FIELD, false, null, "Optional. A comma"
                + " separated list of the name(s) of the table field(s) to be"
                + " dumped.");
    }

    /*
     * (non-Javadoc)
     * 
     * @see org.gusdb.wsf.util.BaseCLI#invoke()
     */
    @Override
    public void execute() throws Exception {
        long start = System.currentTimeMillis();

        String projectId = (String) getOptionValue(ARG_PROJECT_ID);
        String sqlFile = (String) getOptionValue(ARG_SQL_FILE);
        String recordClassName = (String) getOptionValue(ARG_RECORD);
        cacheTable = (String) getOptionValue(ARG_CACHE_TABLE);
        String fieldNames = (String) getOptionValue(ARG_TABLE_FIELD);

        String gusHome = System.getProperty(Utilities.SYSTEM_PROPERTY_GUS_HOME);
        wdkModel = WdkModel.construct(projectId, gusHome);

        String idSql = loadIdSql(sqlFile);
        RecordClass recordClass = wdkModel.getRecordClass(recordClassName);
        Map<String, TableField> tables = recordClass.getTableFieldMap(FieldScope.REPORT_MAKER);
        if (fieldNames != null) { // dump individual table
            String[] names = fieldNames.split(",");
            for (String fieldName : names) {
                fieldName = fieldName.trim();
                TableField table = tables.get(fieldName);
                if (table == null)
                    throw new WdkModelException(
                            "The table field doesn't exist: " + fieldName);
                dumpTable(table, idSql);
            }
        } else { // no table specified, dump all tables
            for (TableField table : tables.values()) {
                System.out.println(table.getName());
                dumpTable(table, idSql);
            }
        }

        long end = System.currentTimeMillis();
        logger.info("totally spent: " + ((end - start) / 1000.0) + " seconds");
    }

    private String loadIdSql(String sqlFile) throws IOException {
        File file = new File(sqlFile);
        StringBuffer sql = new StringBuffer();
        BufferedReader reader = new BufferedReader(new FileReader(file));
        String line;
        while ((line = reader.readLine()) != null) {
            sql.append(line).append("\n");
        }
        reader.close();
        String idSql = sql.toString().trim();
        if (idSql.endsWith(";"))
            idSql = idSql.substring(0, idSql.length() - 1);
        return idSql;
    }

    private void dumpTable(TableField table, String idSql)
            throws WdkModelException, SQLException {
        long start = System.currentTimeMillis();

        if (((SqlQuery) table.getQuery()).isClobRow()) {
            logger.debug("Dumping clobRow table field: " + table.getName());
            String cacheName = createCache(table, idSql);
            insertFromCache(table, cacheName);
            // drop cache table
            DataSource dataSource = wdkModel.getQueryPlatform().getDataSource();
            SqlUtils.executeUpdate(dataSource, "DROP TABLE " + cacheName);
        } else {
            logger.debug("Dumping charRow table field: " + table.getName());
            insertFromSql(table, idSql);
        }

        long end = System.currentTimeMillis();
        logger.info("Dump table [" + table.getName() + "] used: "
                + ((end - start) / 1000.0) + " seconds");
    }

    private String createCache(TableField table, String idSql)
            throws SQLException, WdkModelException {
        String cacheName = "wdkdumptemp";
        String tqName = "tq";
        String idqName = "idq";
        DBPlatform platform = wdkModel.getQueryPlatform();
        DataSource dataSource = platform.getDataSource();
        if (platform.checkTableExists(null, cacheName)) {
            // drop existing table
            SqlUtils.executeUpdate(dataSource, "DROP TABLE " + cacheName);
        }

        String pkColumns = getPkColumns(table.getRecordClass(), idqName);
        String content = getAttributesContentSql(tqName, table);
        StringBuffer sql = new StringBuffer("CREATE TABLE ");
        sql.append(cacheName).append(" NOLOGGING AS SELECT ");
        sql.append(pkColumns).append(',');
        sql.append(content).append(" AS ").append(COLUMN_CONTENT).append(' ');
        sql.append(getJoinedSql(table, idSql, idqName, tqName));

        logger.debug("++++++ create-cache: \n" + sql);
        SqlUtils.executeUpdate(dataSource, sql.toString());
        return cacheName;
    }

    private void insertFromCache(TableField table, String cacheName)
            throws SQLException {
        String pkColumns = getPkColumns(table.getRecordClass(), null);
        StringBuilder sql = new StringBuilder("INSERT /*+ append */ INTO ");
        sql.append(cacheTable).append(getSelectSql(table, pkColumns)).append(
                ',');
        sql.append(FUNCTION_CLOB_CLOB_AGG).append('(').append(COLUMN_CONTENT);
        sql.append(") AS ").append(COLUMN_CONTENT);
        sql.append(" ,sysdate FROM ").append(cacheName);
        sql.append(" GROUP BY ").append(pkColumns);

        logger.debug("++++++ insert-from-cache: \n" + sql);
        DataSource dataSource = wdkModel.getQueryPlatform().getDataSource();
        SqlUtils.executeUpdate(dataSource, sql.toString());
    }

    private String getJoinedSql(TableField table, String idSql, String idqName,
            String tqName) throws WdkModelException {
        String queryName = table.getQuery().getFullName();
        String tableSql = ((SqlQuery) wdkModel.resolveReference(queryName)).getSql();
        String[] pkColumns = table.getRecordClass().getPrimaryKeyAttributeField().getColumnRefs();
        StringBuilder sql = new StringBuilder(" FROM ");
        sql.append('(').append(idSql).append(") ").append(idqName);
        sql.append(", (").append(tableSql).append(") ").append(tqName);
        boolean firstColumn = true;
        for (String column : pkColumns) {
            if (firstColumn) {
                sql.append(" WHERE ");
                firstColumn = false;
            } else sql.append(" AND ");
            sql.append(idqName).append(".").append(column).append(" = ");
            sql.append(tqName).append(".").append(column);
        }
        return sql.toString();
    }

    private void insertFromSql(TableField table, String idSql)
            throws WdkModelException, SQLException {
        String idqName = "idq";
        String tqName = "tq";
        String content = getAttributesContentSql(tqName, table);
        String pkColumns = getPkColumns(table.getRecordClass(), idqName);

        StringBuffer sql = new StringBuffer("INSERT /*+ append */ INTO ");
        sql.append(cacheTable).append(getSelectSql(table, pkColumns));
        sql.append(',').append(FUNCTION_CHAR_CLOB_AGG).append('(');
        sql.append(content).append(") AS ").append(COLUMN_CONTENT).append(" ,sysdate ");
        sql.append(getJoinedSql(table, idSql, idqName, tqName));
        sql.append(" GROUP BY ").append(pkColumns);

        DataSource dataSource = wdkModel.getQueryPlatform().getDataSource();
        logger.debug("++++++ insert-from-sql: \n" + sql);
        SqlUtils.executeUpdate(dataSource, sql.toString());
    }

    private String getSelectSql(TableField table, String pkColumns) {
        String name = table.getName();
        String title = getTableTitle(table);
        StringBuffer sql = new StringBuffer(" SELECT ");
        sql.append(pkColumns).append(", '");
        sql.append(name).append("' AS ").append(COLUMN_FIELD_NAME).append(',');
        sql.append(title).append(" AS ").append(COLUMN_FIELD_TITLE).append(',');
        sql.append("count(*) AS ").append(COLUMN_ROW_COUNT).append(' ');
        return sql.toString();
    }

    private String getPkColumns(RecordClass recordClass, String prefix) {
        StringBuilder sql = new StringBuilder();
        String[] pkColumns = recordClass.getPrimaryKeyAttributeField().getColumnRefs();
        for (String column : pkColumns) {
            if (sql.length() > 0) sql.append(',');
            if (prefix != null) sql.append(prefix).append('.');
            sql.append(column);
        }
        return sql.toString();
    }

    private String getTableTitle(TableField table) {
        StringBuilder sql = new StringBuilder();
        sql.append("TABLE: ").append(table.getDisplayName()).append("\n");
        boolean firstField = true;
        for (AttributeField attribute : table.getAttributeFields(FieldScope.REPORT_MAKER)) {
            if (firstField) firstField = false;
            else sql.append("\t");
            sql.append("[").append(attribute.getDisplayName()).append("]");
        }
        String title = sql.toString().replace("'", "''");
        return "'" + title + "'";
    }

    private String getAttributesContentSql(String tableName, TableField table)
            throws WdkModelException {
        StringBuilder sql = new StringBuilder();
        boolean clobRow = ((SqlQuery) table.getQuery()).isClobRow();
        for (AttributeField attribute : table.getAttributeFields(FieldScope.REPORT_MAKER)) {
            String attributeSql = getAttributeContentSql(tableName, attribute);
            if (clobRow && sql.length() == 0) {
                attributeSql = "TO_CLOB(" + attributeSql + ")";
            } else if (sql.length() > 0) sql.append(" || '\t' || ");
            sql.append(attributeSql);
        }
        return sql.toString();
    }

    private String getAttributeContentSql(String tableName,
            AttributeField attribute) throws WdkModelException {
        if (attribute instanceof ColumnAttributeField)
            return tableName + "." + attribute.getName();

        String text = null;
        if (attribute instanceof PrimaryKeyAttributeField) {
            text = ((PrimaryKeyAttributeField) attribute).getText();
        } else if (attribute instanceof TextAttributeField) {
            text = ((TextAttributeField) attribute).getText();
        } else if (attribute instanceof LinkAttributeField) {
            text = ((LinkAttributeField) attribute).getDisplayText();
        }
        text = "'" + text.replace("'", "''") + "'";
        Collection<AttributeField> children = attribute.getDependents();
        for (AttributeField child : children) {
            String key = "$$" + child.getName() + "$$";
            String replace = getAttributeContentSql(tableName, child);
            text = text.replace(key, "' || " + replace + " || '");
        }
        if (text.startsWith("'' || ")) text = text.substring(6);
        if (text.endsWith(" || ''"))
            text = text.substring(0, text.length() - 6);
        return text.trim();
    }
}
