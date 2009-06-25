/**
 * 
 */
package org.apidb.apicommon.model.report;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.OutputStream;
import java.security.NoSuchAlgorithmException;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

import org.apache.log4j.Logger;
import org.gusdb.wdk.model.AnswerValue;
import org.gusdb.wdk.model.Field;
import org.gusdb.wdk.model.FieldScope;
import org.gusdb.wdk.model.Question;
import org.gusdb.wdk.model.QuestionSet;
import org.gusdb.wdk.model.RecordClass;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.WdkUserException;
import org.gusdb.wdk.model.query.Column;
import org.gusdb.wdk.model.query.Query;
import org.gusdb.wdk.model.query.QuerySet;
import org.gusdb.wdk.model.query.SqlQuery;
import org.gusdb.wdk.model.report.FullRecordReporter;
import org.gusdb.wdk.model.report.Reporter;
import org.gusdb.wdk.model.user.User;
import org.gusdb.wsf.util.BaseCLI;
import org.json.JSONException;

/**
 * @author xingao
 * 
 */
public class FullRecordFileCreator extends BaseCLI {

    private static final String ARG_PROJECT_ID = "model";
    private static final String ARG_SQL_FILE = "sqlFile";
    private static final String ARG_RECORD = "record";
    private static final String ARG_CACHE_TABLE = "cacheTable";
    private static final String ARG_DUMP_FILE = "dumpFile";

    private static final Logger logger = Logger.getLogger(FullRecordCacheCreator.class);

    /**
     * @param args
     * @throws Exception
     */
    public static void main(String[] args) throws Exception {
        String cmdName = System.getProperty("cmdName");
        if (cmdName == null) cmdName = FullRecordFileCreator.class.getName();
        FullRecordFileCreator writer = new FullRecordFileCreator(cmdName,
                "Create the Dump File from dump table");
        try {
            writer.invoke(args);
        } finally {
            System.exit(0);
        }
    }

    private WdkModel wdkModel;

    /**
     * @param command
     * @param description
     */
    protected FullRecordFileCreator(String command, String description) {
        super(command, description);
    }

    /*
     * (non-Javadoc)
     * 
     * @see org.gusdb.wsf.util.BaseCLI#declareOptions()
     */
    @Override
    protected void declareOptions() {
        addSingleValueOption(ARG_PROJECT_ID, true, null, "The ProjectId, which"
                + " should match the directory name under $GUS_HOME, where "
                + "model-config.xml is stored.");

        addSingleValueOption(ARG_SQL_FILE, true, null, "The file that contains"
                + " a sql that returns the primary key columns of the records");

        addSingleValueOption(ARG_RECORD, true, null, "The full name of the "
                + "record class to be dumped.");

        addSingleValueOption(ARG_CACHE_TABLE, true, null, "The name of the "
                + "cache table where the cached results are stored. ");

        addSingleValueOption(ARG_DUMP_FILE, false, null, "The name of the"
                + " output dump file. If not supplied, the dump_table name "
                + " will be used with a '.txt' extension, and saved at the "
                + " current location.");
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
        String cacheTable = (String) getOptionValue(ARG_CACHE_TABLE);
        String dumpFile = (String) getOptionValue(ARG_DUMP_FILE);

        String gusHome = System.getProperty(Utilities.SYSTEM_PROPERTY_GUS_HOME);
        wdkModel = WdkModel.construct(projectId, gusHome);

        String idSql = loadIdSql(sqlFile);
        RecordClass recordClass = wdkModel.getRecordClass(recordClassName);

        if (cacheTable == null)
            cacheTable = "wdk" + recordClass.getType() + "Dump";
        if (dumpFile == null) 
            dumpFile = cacheTable + ".txt";

        Question question = createQuestion(recordClass, idSql);
        User user = wdkModel.getSystemUser();
        Map<String, String> paramValues = new LinkedHashMap<String, String>();
        AnswerValue answerValue = question.makeAnswerValue(user, paramValues);

        OutputStream out = new FileOutputStream(dumpFile);
        Reporter reporter = createReporter(answerValue, cacheTable);
        reporter.write(out);
        out.close();

        long end = System.currentTimeMillis();
        logger.info("full record dump took " + ((end - start) / 1000.0)
                + " seconds");
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

    private Question createQuestion(RecordClass recordClass, String idSql)
            throws WdkModelException, NoSuchAlgorithmException, SQLException,
            JSONException, WdkUserException {
        String name = recordClass.getFullName().replaceAll("\\W", "_");
        QuestionSet questionSet = wdkModel.getQuestionSet(Utilities.INTERNAL_QUESTION_SET);
        Query query = createQuery(recordClass, idSql);
        Question question = new Question();
        question.setName(name + "_dump");
        question.setRecordClass(recordClass);
        question.setQuery(query);
        question.setWdkModel(wdkModel);
        // question.setFullAnswer(true);
        questionSet.addQuestion(question);
        return question;
    }

    private SqlQuery createQuery(RecordClass recordClass, String idSql)
            throws NoSuchAlgorithmException, WdkModelException, SQLException,
            JSONException, WdkUserException {
        String name = recordClass.getFullName().replaceAll("\\W", "_");
        QuerySet querySet = wdkModel.getQuerySet(Utilities.INTERNAL_QUERY_SET);
        SqlQuery query = new SqlQuery();
        query.setName(name + "_dump");
        query.setIsCacheable(false);
        query.setSql(idSql);
        querySet.addQuery(query);
        String[] columnNames = recordClass.getPrimaryKeyAttributeField().getColumnRefs();
        Column[] columns = new Column[columnNames.length];
        for (int i = 0; i < columns.length; i++) {
            Column column = new Column();
            column.setName(columnNames[i]);
            column.setQuery(query);
            query.addColumn(column);
        }
        query.resolveReferences(wdkModel);
        return query;
    }

    private Reporter createReporter(AnswerValue answerValue, String cacheTable)
            throws WdkModelException, NoSuchAlgorithmException, SQLException,
            JSONException, WdkUserException {
        Question question = answerValue.getQuestion();
        Map<String, Field> fields = question.getFields(FieldScope.REPORT_MAKER);
        StringBuffer sbFields = new StringBuffer();
        for (String fieldName : fields.keySet()) {
            if (sbFields.length() > 0) sbFields.append(",");
            sbFields.append(fieldName);
        }

        Map<String, String> properties = new LinkedHashMap<String, String>();
        properties.put(FullRecordCachedReporter.PROPERTY_TABLE_CACHE, cacheTable);

        Map<String, String> config = new LinkedHashMap<String, String>();
        config.put(Reporter.FIELD_FORMAT, "text");
        config.put(FullRecordReporter.FIELD_SELECTED_COLUMNS,
                sbFields.toString());
        config.put(FullRecordReporter.FIELD_HAS_EMPTY_TABLE, "yes");

        int resultSize = answerValue.getResultSize();
        FullRecordCachedReporter reporter = new FullRecordCachedReporter(
                answerValue, 1, resultSize);
        reporter.setProperties(properties);
        reporter.configure(config);
        return reporter;
    }
}
