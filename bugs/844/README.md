# GanttProject Bug [844](https://github.com/bardsoftware/ganttproject/issues/844)

## Patch

```
commit d29a8e79ef744bc75d9e1db79a2dc7ae5c5ff3c7
Author: dbarashev <dbarashev@localhost>
Date:   Wed Feb 5 12:45:06 2014 +0400

    more tolerating and robust CSV parser

diff --git a/ganttproject-tester/test/net/sourceforge/ganttproject/io/CsvImportTest.java b/ganttproject-tester/test/net/sourceforge/ganttproject/io/CsvImportTest.java
index 9e5e1ab..22bdff9 100644
--- a/ganttproject-tester/test/net/sourceforge/ganttproject/io/CsvImportTest.java
+++ b/ganttproject-tester/test/net/sourceforge/ganttproject/io/CsvImportTest.java
@@ -18,6 +18,7 @@ Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */
 package net.sourceforge.ganttproject.io;
 
+import java.io.IOException;
 import java.io.Reader;
 import java.io.StringReader;
 import java.util.concurrent.atomic.AtomicBoolean;
@@ -45,12 +46,13 @@ public class CsvImportTest extends TestCase {
     String header = "A, B";
     String data = "a1, b1";
     final AtomicBoolean wasCalled = new AtomicBoolean(false);
-    GanttCSVOpen.RecordGroup recordGroup = new GanttCSVOpen.RecordGroup(ImmutableSet.<String> of("A", "B")) {
+    GanttCSVOpen.RecordGroup recordGroup = new GanttCSVOpen.RecordGroup("AB", ImmutableSet.<String> of("A", "B")) {
       @Override
-      protected void process(CSVRecord record) {
+      protected boolean doProcess(CSVRecord record) {
         wasCalled.set(true);
         assertEquals("a1", record.get("A"));
         assertEquals("b1", record.get("B"));
+        return true;
       }
     };
     GanttCSVOpen importer = new GanttCSVOpen(createSupplier(Joiner.on('\n').join(header, data)), recordGroup);
@@ -68,25 +70,27 @@ public class CsvImportTest extends TestCase {
     String header1 = "A, B";
     String data1 = "a1, b1";
     final AtomicBoolean wasCalled1 = new AtomicBoolean(false);
-    GanttCSVOpen.RecordGroup recordGroup1 = new GanttCSVOpen.RecordGroup(ImmutableSet.<String> of("A", "B")) {
+    GanttCSVOpen.RecordGroup recordGroup1 = new GanttCSVOpen.RecordGroup("AB", ImmutableSet.<String> of("A", "B")) {
       @Override
-      protected void process(CSVRecord record) {
+      protected boolean doProcess(CSVRecord record) {
         assertEquals("a1", record.get("A"));
         assertEquals("b1", record.get("B"));
         wasCalled1.set(true);
+        return true;
       }
     };
 
     String header2 = "C, D, E";
     String data2 = "c1, d1, e1";
     final AtomicBoolean wasCalled2 = new AtomicBoolean(false);
-    GanttCSVOpen.RecordGroup recordGroup2 = new GanttCSVOpen.RecordGroup(ImmutableSet.<String> of("C", "D", "E")) {
+    GanttCSVOpen.RecordGroup recordGroup2 = new GanttCSVOpen.RecordGroup("CDE", ImmutableSet.<String> of("C", "D", "E")) {
       @Override
-      protected void process(CSVRecord record) {
+      protected boolean doProcess(CSVRecord record) {
         assertEquals("c1", record.get("C"));
         assertEquals("d1", record.get("D"));
         assertEquals("e1", record.get("E"));
         wasCalled2.set(true);
+        return true;
       }
     };
     GanttCSVOpen importer = new GanttCSVOpen(createSupplier(Joiner.on('\n').join(header1, data1, "", header2, data2)),
@@ -94,4 +98,69 @@ public class CsvImportTest extends TestCase {
     importer.load();
     assertTrue(wasCalled1.get() && wasCalled2.get());
   }
+
+  public void testIncompleteHeader() throws IOException {
+    String header = "A, B";
+    String data = "a1, b1";
+    final AtomicBoolean wasCalled = new AtomicBoolean(false);
+    GanttCSVOpen.RecordGroup recordGroup = new GanttCSVOpen.RecordGroup("ABC",
+        ImmutableSet.<String> of("A", "B", "C"), // all fields
+        ImmutableSet.<String> of("A", "B")) { // mandatory fields
+      @Override
+      protected boolean doProcess(CSVRecord record) {
+        wasCalled.set(true);
+        assertEquals("a1", record.get("A"));
+        assertEquals("b1", record.get("B"));
+        return true;
+      }
+    };
+    GanttCSVOpen importer = new GanttCSVOpen(createSupplier(Joiner.on('\n').join(header, data)), recordGroup);
+    importer.load();
+    assertTrue(wasCalled.get());
+  }
+
+  public void testSkipUntilFirstHeader() throws IOException {
+    String notHeader = "FOO, BAR, A";
+    String header = "A, B";
+    String data = "a1, b1";
+    final AtomicBoolean wasCalled = new AtomicBoolean(false);
+    GanttCSVOpen.RecordGroup recordGroup = new GanttCSVOpen.RecordGroup("ABC", ImmutableSet.<String> of("A", "B")) {
+      @Override
+      protected boolean doProcess(CSVRecord record) {
+        wasCalled.set(true);
+        assertEquals("a1", record.get("A"));
+        assertEquals("b1", record.get("B"));
+        return true;
+      }
+    };
+    GanttCSVOpen importer = new GanttCSVOpen(createSupplier(Joiner.on('\n').join(notHeader, header, data)), recordGroup);
+    importer.load();
+    assertTrue(wasCalled.get());
+    assertEquals(1, importer.getSkippedLineCount());
+  }
+
+  public void testSkipLinesWithEmptyMandatoryFields() throws IOException {
+    String header = "A, B, C";
+    String data1 = "a1,,c1";
+    String data2 = "a2,b2,c2";
+    String data3 = ",b3,c3";
+    final AtomicBoolean wasCalled = new AtomicBoolean(false);
+    GanttCSVOpen.RecordGroup recordGroup = new GanttCSVOpen.RecordGroup("ABC",
+        ImmutableSet.<String> of("A", "B", "C"), ImmutableSet.<String> of("A", "B")) {
+      @Override
+      protected boolean doProcess(CSVRecord record) {
+        if (!hasMandatoryFields(record)) {
+          return false;
+        }
+        wasCalled.set(true);
+        assertEquals("a2", record.get("A"));
+        assertEquals("b2", record.get("B"));
+        return true;
+      }
+    };
+    GanttCSVOpen importer = new GanttCSVOpen(createSupplier(Joiner.on('\n').join(header, data1, data2, data3)), recordGroup);
+    importer.load();
+    assertTrue(wasCalled.get());
+    assertEquals(2, importer.getSkippedLineCount());
+  }
 }
diff --git a/ganttproject/src/net/sourceforge/ganttproject/GPLogger.java b/ganttproject/src/net/sourceforge/ganttproject/GPLogger.java
index bc4e533..d2c2b23 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/GPLogger.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/GPLogger.java
@@ -105,6 +105,12 @@ public class GPLogger {
     ourUIFacade = uifacade;
   }
 
+  public static void debug(Logger logger, String format, Object... args) {
+    if (logger.isLoggable(Level.FINE)) {
+      logger.fine(String.format(format, args));
+    }
+  }
+
   public static void setLogFile(String logFileName) {
     try {
       Handler fileHandler = new FileHandler(logFileName, true);
diff --git a/ganttproject/src/net/sourceforge/ganttproject/io/GanttCSVOpen.java b/ganttproject/src/net/sourceforge/ganttproject/io/GanttCSVOpen.java
index aeb3f81..4bf25fb 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/io/GanttCSVOpen.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/io/GanttCSVOpen.java
@@ -18,6 +18,8 @@ along with GanttProject.  If not, see <http://www.gnu.org/licenses/>.
  */
 package net.sourceforge.ganttproject.io;
 
+import static net.sourceforge.ganttproject.GPLogger.debug;
+
 import java.io.File;
 import java.io.FileInputStream;
 import java.io.FileNotFoundException;
@@ -31,6 +33,8 @@ import java.util.List;
 import java.util.Map;
 import java.util.Map.Entry;
 import java.util.Set;
+import java.util.logging.Level;
+import java.util.logging.Logger;
 
 import net.sourceforge.ganttproject.CustomPropertyClass;
 import net.sourceforge.ganttproject.CustomPropertyDefinition;
@@ -67,17 +71,60 @@ import com.google.common.collect.Sets.SetView;
 public class GanttCSVOpen {
   public static abstract class RecordGroup {
     private final Set<String> myFields;
+    private final Set<String> myMandatoryFields;
     private SetView<String> myCustomFields;
+    private final String myName;
 
-    public RecordGroup(Set<String> fields) {
+    public RecordGroup(String name, Set<String> fields) {
+      myName = name;
       myFields = fields;
+      myMandatoryFields = fields;
+    }
+
+    public RecordGroup(String name, Set<String> regularFields, Set<String> mandatoryFields) {
+      myName = name;
+      myFields = regularFields;
+      myMandatoryFields = mandatoryFields;
     }
 
     boolean isHeader(CSVRecord record) {
-      return Sets.newHashSet(record.iterator()).containsAll(myFields);
+      Set<String> thoseFields = Sets.newHashSet();
+      for (Iterator<String> it = record.iterator(); it.hasNext();) {
+        thoseFields.add(it.next());
+      }
+      return thoseFields.containsAll(myMandatoryFields);
+    }
+
+    boolean process(CSVRecord record) {
+      assert record.size() > 0;
+      boolean allEmpty = true;
+      for (Iterator<String> it = record.iterator(); it.hasNext();) {
+        if (!Strings.isNullOrEmpty(it.next())) {
+          allEmpty = false;
+          break;
+        }
+      }
+      if (allEmpty) {
+        return false;
+      }
+      try {
+        return doProcess(record);
+      } catch (Throwable e) {
+        GPLogger.getLogger(GanttCSVOpen.class).log(Level.WARNING, String.format("Failed to process record:\n%s", record), e);
+        return false;
+      }
+    }
+
+    protected boolean hasMandatoryFields(CSVRecord record) {
+      for (String s : myMandatoryFields) {
+        if (Strings.isNullOrEmpty(record.get(s))) {
+          return false;
+        }
+      }
+      return true;
     }
 
-    protected abstract void process(CSVRecord record);
+    protected abstract boolean doProcess(CSVRecord record);
 
     protected void postProcess() {}
 
@@ -88,12 +135,18 @@ public class GanttCSVOpen {
     protected Collection<String> getCustomFields() {
       return myCustomFields;
     }
+
+    @Override
+    public String toString() {
+      return myName;
+    }
   }
   /** List of known (and supported) Task attributes */
   public enum TaskFields {
     ID(TaskDefaultColumn.ID.getNameKey()),
-    NAME("tableColName"), BEGIN_DATE("tableColBegDate"), END_DATE("tableColEndDate"), WEB_LINK("webLink"), NOTES(
-        "notes"), COMPLETION("tableColCompletion"), RESOURCES("resources"), DURATION("tableColDuration"), PREDECESSORS(TaskDefaultColumn.PREDECESSORS.getNameKey());
+    NAME("tableColName"), BEGIN_DATE("tableColBegDate"), END_DATE("tableColEndDate"), WEB_LINK("webLink"),
+    NOTES("notes"), COMPLETION("tableColCompletion"), RESOURCES("resources"), DURATION("tableColDuration"),
+    PREDECESSORS(TaskDefaultColumn.PREDECESSORS.getNameKey()), OUTLINE_NUMBER(TaskDefaultColumn.OUTLINE_NUMBER.getNameKey());
 
     private final String text;
 
@@ -124,7 +177,7 @@ public class GanttCSVOpen {
     }
   }
 
-  private static Collection<String> getFieldNames(Enum[] fieldsEnum) {
+  private static Collection<String> getFieldNames(Enum... fieldsEnum) {
     return Collections2.transform(Arrays.asList(fieldsEnum), new Function<Enum, String>() {
       @Override
       public String apply(Enum input) {
@@ -139,6 +192,8 @@ public class GanttCSVOpen {
 
   private final Supplier<Reader> myInputSupplier;
 
+  private int mySkippedLine;
+
   public GanttCSVOpen(Supplier<Reader> inputSupplier, RecordGroup group) {
     myInputSupplier = inputSupplier;
     myRecordGroups = ImmutableList.of(group);
@@ -172,7 +227,9 @@ public class GanttCSVOpen {
   }
 
   private static RecordGroup createTaskRecordGroup(final TaskManager taskManager, final HumanResourceManager resourceManager) {
-    return new RecordGroup(Sets.newHashSet(getFieldNames(TaskFields.values()))) {
+    return new RecordGroup("Task group",
+        Sets.newHashSet(getFieldNames(TaskFields.values())),
+        Sets.newHashSet(getFieldNames(TaskFields.NAME, TaskFields.BEGIN_DATE))) {
       private Map<Task, String> myAssignmentMap = Maps.newHashMap();
       private Map<Task, String> myPredecessorMap = Maps.newHashMap();
       private Map<String, Task> myTaskIdMap = Maps.newHashMap();
@@ -184,17 +241,9 @@ public class GanttCSVOpen {
       }
 
       @Override
-      protected void process(CSVRecord record) {
-        assert record.size() > 0;
-        boolean allEmpty = true;
-        for (Iterator<String> it = record.iterator(); it.hasNext();) {
-          if (!Strings.isNullOrEmpty(it.next())) {
-            allEmpty = false;
-            break;
-          }
-        }
-        if (allEmpty) {
-          return;
+      protected boolean doProcess(CSVRecord record) {
+        if (!hasMandatoryFields(record)) {
+          return false;
         }
         // Create the task
         TaskManager.TaskBuilder builder = taskManager.newTaskBuilder()
@@ -230,6 +279,7 @@ public class GanttCSVOpen {
             task.getCustomValues().addCustomProperty(def, value);
           }
         }
+        return true;
       }
 
       @Override
@@ -278,7 +328,9 @@ public class GanttCSVOpen {
   }
 
   private static RecordGroup createResourceRecordGroup(final HumanResourceManager resourceManager) {
-    return resourceManager == null ? null : new RecordGroup(Sets.newHashSet(getFieldNames(ResourceFields.values()))) {
+    return resourceManager == null ? null : new RecordGroup("Resource group",
+        Sets.newHashSet(getFieldNames(ResourceFields.values())),
+        Sets.newHashSet(getFieldNames(ResourceFields.ID, ResourceFields.NAME))) {
       @Override
       public void setHeader(List<String> header) {
         super.setHeader(header);
@@ -286,7 +338,10 @@ public class GanttCSVOpen {
       }
 
       @Override
-      protected void process(CSVRecord record) {
+      protected boolean doProcess(CSVRecord record) {
+        if (!hasMandatoryFields(record)) {
+          return false;
+        }
         assert record.size() > 0;
         HumanResource hr = resourceManager.newResourceBuilder().withName(record.get(ResourceFields.NAME.toString())).withID(
             record.get(ResourceFields.ID.toString())).withEmail(record.get(ResourceFields.EMAIL.toString())).withPhone(
@@ -297,6 +352,7 @@ public class GanttCSVOpen {
             hr.addCustomProperty(resourceManager.getCustomPropertyManager().getCustomPropertyDefinition(customField), value);
           }
         }
+        return true;
       }
     };
   }
@@ -308,12 +364,14 @@ public class GanttCSVOpen {
    *           on parse error or input read-failure
    */
   public boolean load() throws IOException {
+    final Logger logger = GPLogger.getLogger(GanttCSVOpen.class);
     CSVParser parser = new CSVParser(myInputSupplier.get(),
         CSVFormat.DEFAULT.withEmptyLinesIgnored(false).withSurroundingSpacesIgnored(true));
     int numGroup = 0;
     RecordGroup currentGroup = null;
     boolean searchHeader = true;
     List<CSVRecord> records = parser.getRecords();
+    debug(logger, "[CSV] read %d records. Searching for a header of %s", records.size(), myRecordGroups.get(numGroup));
     for (CSVRecord record : records) {
       if (record.size() == 0) {
         // If line is empty then current record group is probably finished.
@@ -322,8 +380,10 @@ public class GanttCSVOpen {
         continue;
       }
       if (searchHeader) {
+        debug(logger, "%s\n", record);
         // Record is not empty and we're searching for header.
         if (numGroup < myRecordGroups.size() && myRecordGroups.get(numGroup).isHeader(record)) {
+          debug(logger, "[CSV] ^^^ This seems to be a header");
           // If next group acknowledges the header, then we give it the turn,
           // otherwise it was just an empty line in the current group
           searchHeader = false;
@@ -333,10 +393,12 @@ public class GanttCSVOpen {
           numGroup++;
           continue;
         }
+      }
+      if (currentGroup != null && currentGroup.doProcess(record)) {
         searchHeader = false;
+      } else {
+        mySkippedLine++;
       }
-      assert currentGroup != null;
-      currentGroup.process(record);
     }
     for (RecordGroup group : myRecordGroups) {
       group.postProcess();
@@ -344,4 +406,8 @@ public class GanttCSVOpen {
     // Succeeded
     return true;
   }
+
+  int getSkippedLineCount() {
+    return mySkippedLine;
+  }
 }
```
