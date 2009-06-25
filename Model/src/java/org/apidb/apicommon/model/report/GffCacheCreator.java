/**
 * 
 */
package org.apidb.apicommon.model.report;

import java.io.IOException;

import org.apache.log4j.Logger;
import org.gusdb.wdk.model.RecordClass;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.query.SqlQuery;

/**
 * @author xingao
 * 
 */
public class GffCacheCreator extends DumpCreator {


    private static final String ARG_PROJECT_ID = "model";
    private static final String ARG_SQL_FILE = "sqlFile";
    private static final String ARG_RECORD = "record";
    private static final String ARG_TABLE_FIELD = "field";
    private static final String ARG_CACHE_TABLE = "cacheTable";

    private static final String COLUMN_FIELD_NAME = "field_name";
    private static final String COLUMN_FIELD_TITLE = "field_title";
    private static final String COLUMN_CONTENT = "content";
    private static final String COLUMN_ROW_COUNT = "row_count";
    
    //private static final String TABLE_

    private static final String FUNCTION_CHAR_CLOB_AGG = "char_clob_agg";
    private static final String FUNCTION_CLOB_CLOB_AGG = "clob_clob_agg";

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

    public GffCacheCreator(WdkModel wdkModel) {

    }

    public void dump(String sqlFile) throws WdkModelException, IOException {
        RecordClass recordClass = (RecordClass) wdkModel.resolveReference("GeneRecordClasses.GeneRecordClass");
        //String idSql = loadIdSql(sqlFile);
    }
    
    private void dumpGeneAttributes(String idSql, SqlQuery query) {
        
    }
    
    private void dumpRnaTable(String idSql, SqlQuery query) {
        
    }
    
    private void dumpCdsTable(String idSql, SqlQuery query) {
        
    }
    
    private void dumpExonTable(String idSql, SqlQuery query) {
        
    }
    
    private void dumpTranscript(String idSql, SqlQuery query) {
        
    }
    
    private void dumpProteinSequence(String idSql, SqlQuery query) {
        
    }
    
    private void dumpAliases(String idSql, SqlQuery query, String[] pkColumns) {
        StringBuffer sql = new StringBuffer("SELECT ");
        for(String pkColumn : pkColumns) { 
            sql.append(pkColumn).append(", ");
        }
        sql.append("apidb.tab_to_string(CAST(COLLECT(trim(to_char(");
        
        sql.append("))) AS apidb.varchartab), ', ')");
    }
    
    private void dumpEcNumbers(String idSql, SqlQuery query) {
        
    }
    
    private void dumpGoTerms(String idSql, SqlQuery query) {
        
    }
    
    private void dumpDbxrefs(String idSql, SqlQuery query) {
        
    }
}
