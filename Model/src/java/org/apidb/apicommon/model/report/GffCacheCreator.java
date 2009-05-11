/**
 * 
 */
package org.apidb.apicommon.model.report;

import java.io.IOException;

import org.gusdb.wdk.model.RecordClass;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.query.SqlQuery;

/**
 * @author xingao
 * 
 */
public class GffCacheCreator extends DumpCreator {

    private WdkModel wdkModel;

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
    
    private void dumpAliases(String idSql, SqlQuery query) {
        
    }
    
    private void dumpEcNumbers(String idSql, SqlQuery query) {
        
    }
    
    private void dumpGoTerms(String idSql, SqlQuery query) {
        
    }
    
    private void dumpDbxrefs(String idSql, SqlQuery query) {
        
    }
}
