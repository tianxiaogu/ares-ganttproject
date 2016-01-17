# GanttProject Bug [552](https://github.com/bardsoftware/ganttproject/issues/552)

## Steps

1. Launch the buggy version of ganttproject.
2. Create a new task.
3. Click `Resource Chart` tab.
4. Right click and then click `New Resource`
5. Click `Custom Columns` tab.
6. Add a custom column, e.g., `col1`
7. Save this file to `Bug552.gan`
8. Click `new` in Menu
9. Try to import the pre-saved `Bug552.gan`

## Patch

```
commit adc2253822bf3c46ab7e0c0667d783647767d2a7
Author: dbarashev <dbarashev@localhost>
Date:   Wed Jul 18 18:12:42 2012 +0400

    fixes crashes when importing .gan files with custom columns
    makes file open working through file import, so that use the same code
    Update issue #552

diff --git a/ganttproject/src/net/sourceforge/ganttproject/GanttProject.java b/ganttproject/src/net/sourceforge/ganttproject/GanttProject.java
index 7d2662f..af65262 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/GanttProject.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/GanttProject.java
@@ -644,7 +644,9 @@ public class GanttProject extends GanttProjectBase implements ResourceView, Gant
 
   @Override
   public void open(Document document) throws IOException, DocumentException {
-    document.read();
+    if (!tryImportDocument(document)) {
+      return;
+    }
     myMRU.add(document, true);
     projectDocument = document;
     setTitle(language.getText("appliTitle") + " [" + document.getFileName() + "]");
diff --git a/ganttproject/src/net/sourceforge/ganttproject/GanttProjectBase.java b/ganttproject/src/net/sourceforge/ganttproject/GanttProjectBase.java
index b37f6cd..224f828 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/GanttProjectBase.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/GanttProjectBase.java
@@ -78,7 +78,7 @@ import net.sourceforge.ganttproject.undo.UndoManagerImpl;
  * views through interfaces. This class is intentionally package local to
  * prevent using it in other packages (use interfaces rather than concrete
  * implementations!)
- * 
+ *
  * @author dbarashev
  */
 abstract class GanttProjectBase extends JFrame implements IGanttProject, UIFacade {
@@ -133,6 +133,10 @@ abstract class GanttProjectBase extends JFrame implements IGanttProject, UIFacad
         return getUIFacade().getTaskTree().getVisibleFields();
       }
 
+      @Override
+      protected TableHeaderUIFacade getResourceVisibleFields() {
+        return getUIFacade().getResourceTree().getVisibleFields();
+      }
     };
     myUndoManager = new UndoManagerImpl(this, null, myDocumentManager) {
       @Override
diff --git a/ganttproject/src/net/sourceforge/ganttproject/GanttProjectImpl.java b/ganttproject/src/net/sourceforge/ganttproject/GanttProjectImpl.java
index 81f4ebe..c591db8 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/GanttProjectImpl.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/GanttProjectImpl.java
@@ -246,7 +246,7 @@ public class GanttProjectImpl implements IGanttProject {
   }
 
   @Override
-  public CustomColumnsManager getTaskCustomColumnManager() {
+  public CustomPropertyManager getTaskCustomColumnManager() {
     return myTaskCustomColumnManager;
   }
 
diff --git a/ganttproject/src/net/sourceforge/ganttproject/document/DocumentCreator.java b/ganttproject/src/net/sourceforge/ganttproject/document/DocumentCreator.java
index c1f6ed3..7678cb6 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/document/DocumentCreator.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/document/DocumentCreator.java
@@ -26,7 +26,7 @@ import net.sourceforge.ganttproject.parser.ParserFactory;
 /**
  * This is a helper class, to create new instances of Document easily. It
  * chooses the correct implementation based on the given path.
- * 
+ *
  * @author Michael Haeusler (michael at akatose.de)
  */
 public class DocumentCreator implements DocumentManager {
@@ -45,7 +45,7 @@ public class DocumentCreator implements DocumentManager {
   /**
    * Creates an HttpDocument if path starts with "http://" or "https://";
    * creates a FileDocument otherwise.
-   * 
+   *
    * @param path
    *          path to the document
    * @return an implementation of the interface Document
@@ -57,7 +57,7 @@ public class DocumentCreator implements DocumentManager {
   /**
    * Creates an HttpDocument if path starts with "http://" or "https://";
    * creates a FileDocument otherwise.
-   * 
+   *
    * @param path
    *          path to the document
    * @param user
@@ -87,7 +87,7 @@ public class DocumentCreator implements DocumentManager {
   public Document getDocument(String path) {
     Document physicalDocument = createDocument(path);
     Document proxyDocument = new ProxyDocument(this, physicalDocument, myProject, myUIFacade, getVisibleFields(),
-        getParserFactory());
+        getResourceVisibleFields(), getParserFactory());
     return proxyDocument;
   }
 
@@ -95,7 +95,7 @@ public class DocumentCreator implements DocumentManager {
   public Document getDocument(String path, String userName, String password) {
     Document physicalDocument = createDocument(path, userName, password);
     Document proxyDocument = new ProxyDocument(this, physicalDocument, myProject, myUIFacade, getVisibleFields(),
-        getParserFactory());
+        getResourceVisibleFields(), getParserFactory());
     return proxyDocument;
   }
 
@@ -144,6 +144,10 @@ public class DocumentCreator implements DocumentManager {
     return null;
   }
 
+  protected TableHeaderUIFacade getResourceVisibleFields() {
+    return null;
+  }
+
   @Override
   public void addToRecentDocuments(Document document) {
     // TODO Auto-generated method stub
diff --git a/ganttproject/src/net/sourceforge/ganttproject/document/ProxyDocument.java b/ganttproject/src/net/sourceforge/ganttproject/document/ProxyDocument.java
index 8fdc4bd..37a887a 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/document/ProxyDocument.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/document/ProxyDocument.java
@@ -71,16 +71,19 @@ class ProxyDocument implements Document {
 
   private PortfolioImpl myPortfolio;
 
-  private final TableHeaderUIFacade myVisibleFields;
+  private final TableHeaderUIFacade myTaskVisibleFields;
+
+  private final TableHeaderUIFacade myResourceVisibleFields;
 
   ProxyDocument(DocumentCreator creator, Document physicalDocument, IGanttProject project, UIFacade uiFacade,
-      TableHeaderUIFacade visibleFields, ParserFactory parserFactory) {
+      TableHeaderUIFacade taskVisibleFields, TableHeaderUIFacade resourceVisibleFields, ParserFactory parserFactory) {
     myPhysicalDocument = physicalDocument;
     myProject = project;
     myUIFacade = uiFacade;
     myParserFactory = parserFactory;
     myCreator = creator;
-    myVisibleFields = visibleFields;
+    myTaskVisibleFields = taskVisibleFields;
+    myResourceVisibleFields = resourceVisibleFields;
   }
 
   @Override
@@ -291,11 +294,11 @@ class ProxyDocument implements Document {
       CustomPropertiesTagHandler customPropHandler = new CustomPropertiesTagHandler(opener.getContext(),
           getTaskManager());
       opener.addTagHandler(customPropHandler);
-      TaskDisplayColumnsTagHandler taskDisplayHandler = new TaskDisplayColumnsTagHandler(myVisibleFields);
+      TaskDisplayColumnsTagHandler taskDisplayHandler = new TaskDisplayColumnsTagHandler(myTaskVisibleFields);
       opener.addTagHandler(taskDisplayHandler);
 
       TaskDisplayColumnsTagHandler resourceViewHandler = new TaskDisplayColumnsTagHandler(
-          getUIFacade().getResourceTree().getVisibleFields(), "field", "id", "order", "width", "visible");
+          myResourceVisibleFields, "field", "id", "order", "width", "visible");
       opener.addTagHandler(resourceViewHandler);
       opener.addParsingListener(resourceViewHandler);
 
diff --git a/ganttproject/src/net/sourceforge/ganttproject/importer/ImporterFromGanttFile.java b/ganttproject/src/net/sourceforge/ganttproject/importer/ImporterFromGanttFile.java
index 8a26aa1..0773dcd 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/importer/ImporterFromGanttFile.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/importer/ImporterFromGanttFile.java
@@ -107,6 +107,7 @@ public class ImporterFromGanttFile extends ImporterBase implements Importer {
   private void run(File selectedFile, IGanttProject targetProject, BufferProject bufferProject) {
     openDocument(targetProject, bufferProject, getUiFacade(), selectedFile);
     getUiFacade().getTaskTree().getVisibleFields().importData(bufferProject.getVisibleFields());
+    getUiFacade().getResourceTree().getVisibleFields().importData(bufferProject.myResourceVisibleFields);
   }
 
   private static class TaskFieldImpl implements TableHeaderUIFacade.Column {
@@ -196,6 +197,7 @@ public class ImporterFromGanttFile extends ImporterBase implements Importer {
     final TaskManager myTaskManager;
     final UIFacade myUIfacade;
     private final TableHeaderUIFacade myVisibleFields = new VisibleFieldsImpl();
+    private final TableHeaderUIFacade myResourceVisibleFields = new VisibleFieldsImpl();
 
     BufferProject(IGanttProject targetProject, UIFacade uiFacade) {
       myDocumentManager = new DocumentCreator(this, uiFacade, this) {
@@ -203,6 +205,10 @@ public class ImporterFromGanttFile extends ImporterBase implements Importer {
         protected TableHeaderUIFacade getVisibleFields() {
           return myVisibleFields;
         }
+        @Override
+        protected TableHeaderUIFacade getResourceVisibleFields() {
+          return myResourceVisibleFields;
+        }
       };
       myTaskManager = targetProject.getTaskManager().emptyClone();
       myUIfacade = uiFacade;
@@ -233,8 +239,8 @@ public class ImporterFromGanttFile extends ImporterBase implements Importer {
     }
 
     @Override
-    public CustomColumnsManager getTaskCustomColumnManager() {
-      return super.getTaskCustomColumnManager();
+    public CustomPropertyManager getTaskCustomColumnManager() {
+      return myTaskManager.getCustomPropertyManager();
     }
   }
 
diff --git a/ganttproject/src/net/sourceforge/ganttproject/task/TaskManagerImpl.java b/ganttproject/src/net/sourceforge/ganttproject/task/TaskManagerImpl.java
index ccedd94..8e484c6 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/task/TaskManagerImpl.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/task/TaskManagerImpl.java
@@ -10,6 +10,7 @@ import java.util.Arrays;
 import java.util.Calendar;
 import java.util.Date;
 import java.util.HashMap;
+import java.util.LinkedHashMap;
 import java.util.List;
 import java.util.Map;
 import java.util.concurrent.atomic.AtomicInteger;
@@ -774,7 +775,7 @@ public class TaskManagerImpl implements TaskManager {
   public Map<Task, Task> importData(TaskManager taskManager,
       Map<CustomPropertyDefinition, CustomPropertyDefinition> customPropertyMapping) {
     Task importRoot = taskManager.getRootTask();
-    Map<Task, Task> original2imported = new HashMap<Task, Task>();
+    Map<Task, Task> original2imported = new LinkedHashMap<Task, Task>();
     importData(importRoot, getRootTask(), customPropertyMapping, original2imported);
     TaskDependency[] deps = taskManager.getDependencyCollection().getDependencies();
     for (int i = 0; i < deps.length; i++) {
@@ -800,7 +801,7 @@ public class TaskManagerImpl implements TaskManager {
   private void importData(Task importRoot, Task root,
       Map<CustomPropertyDefinition, CustomPropertyDefinition> customPropertyMapping, Map<Task, Task> original2imported) {
     Task[] nested = importRoot.getManager().getTaskHierarchy().getNestedTasks(importRoot);
-    for (int i = nested.length - 1; i >= 0; i--) {
+    for (int i = 0; i < nested.length; i++) {
       Task nextImported = getTask(nested[i].getTaskID()) == null ? createTask(nested[i].getTaskID()) : createTask();
       registerTask(nextImported);
       nextImported.setName(nested[i].getName());
diff --git a/ganttproject/src/net/sourceforge/ganttproject/task/hierarchy/TaskHierarchyItem.java b/ganttproject/src/net/sourceforge/ganttproject/task/hierarchy/TaskHierarchyItem.java
index d6f6c4e..7cb0d4a 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/task/hierarchy/TaskHierarchyItem.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/task/hierarchy/TaskHierarchyItem.java
@@ -3,7 +3,7 @@ Copyright 2003-2012 Dmitry Barashev, GanttProject Team
 
 This file is part of GanttProject, an opensource project management tool.
 
-GanttProject is free software: you can redistribute it and/or modify 
+GanttProject is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
@@ -20,6 +20,8 @@ package net.sourceforge.ganttproject.task.hierarchy;
 
 import java.util.ArrayList;
 
+import com.google.common.collect.Lists;
+
 import net.sourceforge.ganttproject.task.Task;
 
 public class TaskHierarchyItem {
@@ -58,7 +60,7 @@ public class TaskHierarchyItem {
       for (TaskHierarchyItem nested = myFirstNestedItem; nested != null; nested = nested.myNextSiblingItem) {
         tempList.add(nested);
       }
-      result = tempList.toArray(EMPTY_ARRAY);
+      result = Lists.reverse(tempList).toArray(EMPTY_ARRAY);
     }
     return result;
   }
```
