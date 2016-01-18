# GanttProject Bug [577](https://github.com/bardsoftware/ganttproject/issues/577)


## Patch

```
commit f0b13e51ca4ffe1433ac724d5191f0af7d906f74
Author: dbarashev <dbarashev@localhost>
Date:   Wed Sep 5 00:59:32 2012 +0400

    fixes issue #577
    refactoring: holy shit in paste code which messes about with tree nodes replaced with model-driven approach. Apparently we already have a listener which inserts nodes just fine

diff --git a/ganttproject/src/net/sourceforge/ganttproject/GanttProject.java b/ganttproject/src/net/sourceforge/ganttproject/GanttProject.java
index 344b3c2..c1e51a6 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/GanttProject.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/GanttProject.java
@@ -460,7 +460,6 @@ public class GanttProject extends GanttProjectBase implements ResourceView, Gant
     area.repaint();
     getResourcePanel().area.repaint();
 
-    this.tree.changeLanguage(language);
     CustomColumnsStorage.changeLanguage(language);
 
     applyComponentOrientation(language.getComponentOrientation());
diff --git a/ganttproject/src/net/sourceforge/ganttproject/GanttTask.java b/ganttproject/src/net/sourceforge/ganttproject/GanttTask.java
index af9de05..51624f6 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/GanttTask.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/GanttTask.java
@@ -55,11 +55,11 @@ public class GanttTask extends TaskImpl implements Serializable {
 
   /**
    * Will make a copy of the given GanttTask
-   * 
+   *
    * @param copy
    *          task to copy
    */
-  public GanttTask(GanttTask copy) {
+  public GanttTask(TaskImpl copy) {
     super(copy, false);
     enableEvents(true);
   }
diff --git a/ganttproject/src/net/sourceforge/ganttproject/GanttTree2.java b/ganttproject/src/net/sourceforge/ganttproject/GanttTree2.java
index 611c215..13141f8 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/GanttTree2.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/GanttTree2.java
@@ -53,11 +53,9 @@ import java.awt.image.BufferedImage;
 import java.io.IOException;
 import java.util.ArrayList;
 import java.util.Arrays;
-import java.util.HashMap;
 import java.util.HashSet;
 import java.util.Iterator;
 import java.util.List;
-import java.util.Map;
 import java.util.logging.Level;
 
 import javax.swing.AbstractAction;
@@ -100,12 +98,12 @@ import net.sourceforge.ganttproject.action.task.TaskUnindentAction;
 import net.sourceforge.ganttproject.action.task.TaskUnlinkAction;
 import net.sourceforge.ganttproject.chart.Chart;
 import net.sourceforge.ganttproject.chart.VisibleNodesFilter;
+import net.sourceforge.ganttproject.chart.gantt.ClipboardTaskProcessor;
 import net.sourceforge.ganttproject.delay.Delay;
 import net.sourceforge.ganttproject.delay.DelayObserver;
 import net.sourceforge.ganttproject.gui.TableHeaderUIFacade;
 import net.sourceforge.ganttproject.gui.TaskTreeUIFacade;
 import net.sourceforge.ganttproject.gui.UIFacade;
-import net.sourceforge.ganttproject.language.GanttLanguage;
 import net.sourceforge.ganttproject.task.Task;
 import net.sourceforge.ganttproject.task.TaskManager;
 import net.sourceforge.ganttproject.task.TaskNode;
@@ -114,7 +112,6 @@ import net.sourceforge.ganttproject.task.TaskSelectionManager.Listener;
 import net.sourceforge.ganttproject.task.algorithm.AdjustTaskBoundsAlgorithm;
 import net.sourceforge.ganttproject.task.algorithm.RecalculateTaskScheduleAlgorithm;
 import net.sourceforge.ganttproject.task.dependency.TaskDependency;
-import net.sourceforge.ganttproject.task.dependency.TaskDependencyConstraint;
 import net.sourceforge.ganttproject.task.dependency.TaskDependencyException;
 import net.sourceforge.ganttproject.task.event.TaskListenerAdapter;
 import net.sourceforge.ganttproject.undo.GPUndoManager;
@@ -134,9 +131,6 @@ public class GanttTree2 extends TreeTableContainer<Task, GanttTreeTable, GanttTr
   /** Pointer of application */
   private final GanttProject myProject;
 
-  /** The used language */
-  private static GanttLanguage language = GanttLanguage.getInstance();
-
   private TreePath dragPath = null;
 
   private BufferedImage ghostImage = null; // The 'drag image'
@@ -160,6 +154,8 @@ public class GanttTree2 extends TreeTableContainer<Task, GanttTreeTable, GanttTr
 
   private boolean isOnTaskSelectionEventProcessing;
 
+  private ClipboardTaskProcessor myClipboardProcessor;
+
   private static Pair<GanttTreeTable, GanttTreeTableModel> createTreeTable(IGanttProject project, UIFacade uiFacade) {
     GanttTreeTableModel tableModel = new GanttTreeTableModel(project.getTaskManager(),
         project.getTaskCustomColumnManager());
@@ -206,6 +202,7 @@ public class GanttTree2 extends TreeTableContainer<Task, GanttTreeTable, GanttTr
     myMoveDownAction = new TaskMoveDownAction(taskManager, selectionManager, uiFacade, this);
     getTreeTable().setupActionMaps(myMoveUpAction, myMoveDownAction, myIndentAction, myUnindentAction, newAction,
         myProject.getCutAction(), myProject.getCopyAction(), myProject.getPasteAction(), propertiesAction, deleteAction);
+    myClipboardProcessor = new ClipboardTaskProcessor(myTaskManager);
   }
 
   @Override
@@ -314,11 +311,6 @@ public class GanttTree2 extends TreeTableContainer<Task, GanttTreeTable, GanttTr
     getTreeTable().getTreeTable().editingCanceled(new ChangeEvent(getTreeTable().getTreeTable()));
   }
 
-  public void changeLanguage(GanttLanguage ganttLanguage) {
-    language = ganttLanguage;
-    // this.treetable.changeLanguage(language);
-  }
-
   private void initRootNode() {
     getRootNode().setUserObject(myTaskManager.getRootTask());
   }
@@ -450,13 +442,6 @@ public class GanttTree2 extends TreeTableContainer<Task, GanttTreeTable, GanttTr
     // getTreeModel().reload();
   }
 
-  private void selectTasks(List<Task> tasksList) {
-    clearSelection();
-    for (Task t : tasksList) {
-      setSelected(t, false);
-    }
-  }
-
   @Override
   public void setSelected(Task task, boolean clear) {
     if (clear) {
@@ -816,10 +801,6 @@ public class GanttTree2 extends TreeTableContainer<Task, GanttTreeTable, GanttTr
 
   private List<TaskDependency> cpDependencies;
 
-  private Map<Integer, Integer> mapOriginalIDCopyID;
-
-  private int where = -1;
-
   private AbstractAction[] myTreeActions;
 
   /** Cut the current selected tree node */
@@ -840,7 +821,7 @@ public class GanttTree2 extends TreeTableContainer<Task, GanttTreeTable, GanttTr
             if (current != null) {
               cpNodesArrayList.add(current);
               parent = (MutableTreeTableNode) node.getParent();
-              where = parent.getIndex(current);
+              //where = parent.getIndex(current);
               removeCurrentNode(current);
               taskFather = (GanttTask) parent.getUserObject();
               AdjustTaskBoundsAlgorithm alg = myTaskManager.getAlgorithmCollection().getAdjustTaskBoundsAlgorithm();
@@ -893,125 +874,21 @@ public class GanttTree2 extends TreeTableContainer<Task, GanttTreeTable, GanttTr
       getUndoManager().undoableEdit("Paste", new Runnable() {
         @Override
         public void run() {
-          TaskNode current = (TaskNode) getSelectedTaskNode();
-          List<Task> tasksList = new ArrayList<Task>();
-          if (current == null) {
-            current = (TaskNode) getRootNode();
+          DefaultMutableTreeTableNode pasteRoot = getSelectedTaskNode();
+          if (pasteRoot == null) {
+            pasteRoot = getRootNode();
           }
-
-          mapOriginalIDCopyID = new HashMap<Integer, Integer>();
-
-          for (int i = cpNodesArrayList.size() - 1; i >= 0; i--) {
-            if (hasProjectTaskParent(current)) {
-              ((Task) cpNodesArrayList.get(i).getUserObject()).setProjectTask(false);
-            }
-            // this will add new custom columns to the newly created task.
-            TreeNode sel = getSelectedTaskNode();
-            TreeNode parent = null;
-            if (sel != null) {
-              parent = sel.getParent();
-              if (parent != null) {
-                where = parent.getIndex(sel);
-              }
-            }
-            tasksList.add((Task) insertClonedNode(
-                current == getRootNode() ? current : (DefaultMutableTreeTableNode) current.getParent(),
-                cpNodesArrayList.get(i), where + 1, true).getUserObject());
-          }
-          if (cpDependencies != null) {
-            for (TaskDependency td : cpDependencies) {
-              Task dependee = td.getDependee();
-              Task dependant = td.getDependant();
-              TaskDependencyConstraint constraint = td.getConstraint();
-              boolean hasDependeeNode = false;
-              boolean hasDependantNode = false;
-              for (MutableTreeTableNode node : allNodes) {
-                Object userObject = node.getUserObject();
-                if (dependant.equals(userObject)) {
-                  hasDependantNode = true;
-                }
-                if (dependee.equals(userObject)) {
-                  hasDependeeNode = true;
-                }
-              }
-              if (hasDependantNode && hasDependeeNode) {
-                try {
-                  TaskDependency dep = myTaskManager.getDependencyCollection().createDependency(
-                      myTaskManager.getTask(mapOriginalIDCopyID.get(new Integer(dependant.getTaskID())).intValue()),
-                      myTaskManager.getTask(mapOriginalIDCopyID.get(new Integer(dependee.getTaskID())).intValue()),
-                      myTaskManager.createConstraint(constraint.getType()));
-                  dep.setDifference(td.getDifference());
-                  dep.setHardness(td.getHardness());
-                } catch (TaskDependencyException e) {
-                  myUIFacade.showErrorDialog(e);
-                }
-              }
-            }
+          List<Task> pasted = myClipboardProcessor.paste((Task)pasteRoot.getUserObject(), cpNodesArrayList, cpDependencies);
+          mySelectionManager.clear();
+          for (Task t : pasted) {
+            mySelectionManager.addTask(t);
           }
-          selectTasks(tasksList);
         }
       });
       myProject.refreshProjectInformation();
     }
   }
 
-  // TODO Maybe place method in Task?
-  /** @return true if the task has a parent which is a ProjectTask */
-  private boolean hasProjectTaskParent(TaskNode task) {
-    DefaultMutableTreeTableNode parent = (DefaultMutableTreeTableNode) task.getParent();
-    while (parent != null) {
-      if (((Task) parent.getUserObject()).isProjectTask()) {
-        return true;
-      }
-      parent = (DefaultMutableTreeTableNode) parent.getParent();
-    }
-    return false;
-  }
-
-  /** Insert the cloned node and its children */
-  private TaskNode insertClonedNode(DefaultMutableTreeTableNode parent, DefaultMutableTreeTableNode child,
-      int location, boolean first) {
-    if (parent == null) {
-      return null; // it is the root node
-    }
-    if (first) {
-      GanttTask _t = (GanttTask) (parent.getUserObject());
-      if (_t.isMilestone()) {
-        _t.setMilestone(false);
-        GanttTask _c = (GanttTask) (child.getUserObject());
-        _t.setLength(_c.getLength());
-        _t.setStart(_c.getStart());
-      }
-    }
-
-    GanttTask originalTask = (GanttTask) child.getUserObject();
-    GanttTask newTask = new GanttTask(originalTask);
-
-    String newName = language.formatText("task.copy.prefix", language.getText("copy2"), newTask.getName());
-    newTask.setName(newName);
-
-    mapOriginalIDCopyID.put(new Integer(originalTask.getTaskID()), new Integer(newTask.getTaskID()));
-
-    myTaskManager.registerTask(newTask);
-
-    DefaultMutableTreeTableNode cloneChildNode = new TaskNode(newTask);
-
-    for (int i = 0; i < child.getChildCount(); i++) {
-      insertClonedNode(cloneChildNode, (DefaultMutableTreeTableNode) child.getChildAt(i), i, false);
-    }
-
-    if (parent.getChildCount() < location) {
-      location = parent.getChildCount();
-    }
-
-    getTreeModel().insertNodeInto(cloneChildNode, parent, location);
-
-    getTreeTable().getTree().scrollPathToVisible(TreeUtil.createPath(cloneChildNode));
-
-    newTask.setExpand(false);
-    return (TaskNode) cloneChildNode;
-  }
-
   private void forwardScheduling() {
     RecalculateTaskScheduleAlgorithm alg = myTaskManager.getAlgorithmCollection().getRecalculateTaskScheduleAlgorithm();
     try {
diff --git a/ganttproject/src/net/sourceforge/ganttproject/TaskModelModificationListener.java b/ganttproject/src/net/sourceforge/ganttproject/TaskModelModificationListener.java
index a73830c..0512035 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/TaskModelModificationListener.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/TaskModelModificationListener.java
@@ -53,8 +53,6 @@ public class TaskModelModificationListener extends TaskListenerAdapter {
   public void taskAdded(TaskHierarchyEvent e) {
     myGanttProject.setModified();
     myUiFacade.setViewIndex(UIFacade.GANTT_INDEX);
-    myUiFacade.getTaskTree().startDefaultEditing(e.getTask());
-
     myGanttProject.getTaskManager().getAlgorithmCollection().getRecalculateTaskCompletionPercentageAlgorithm().run(e.getTask());
     myUiFacade.refresh();
   }
diff --git a/ganttproject/src/net/sourceforge/ganttproject/action/task/TaskNewAction.java b/ganttproject/src/net/sourceforge/ganttproject/action/task/TaskNewAction.java
index b8df260..fef77c8 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/action/task/TaskNewAction.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/action/task/TaskNewAction.java
@@ -58,9 +58,10 @@ public class TaskNewAction extends GPAction {
         }
 
         Task selectedTask = selection.isEmpty() ? null : selection.get(0);
-        getTaskManager().newTaskBuilder()
+        Task newTask = getTaskManager().newTaskBuilder()
             .withColor(getUIFacade().getGanttChart().getTaskDefaultColorOption().getValue())
             .withPrevSibling(selectedTask).withStartDate(getUIFacade().getGanttChart().getStartDate()).build();
+        myUiFacade.getTaskTree().startDefaultEditing(newTask);
       }
     });
   }
diff --git a/ganttproject/src/net/sourceforge/ganttproject/chart/gantt/ClipboardTaskProcessor.java b/ganttproject/src/net/sourceforge/ganttproject/chart/gantt/ClipboardTaskProcessor.java
new file mode 100644
index 0000000..b774967
--- /dev/null
+++ b/ganttproject/src/net/sourceforge/ganttproject/chart/gantt/ClipboardTaskProcessor.java
@@ -0,0 +1,99 @@
+/*
+Copyright 2012 GanttProject Team
+
+This file is part of GanttProject, an opensource project management tool.
+
+GanttProject is free software: you can redistribute it and/or modify
+it under the terms of the GNU General Public License as published by
+the Free Software Foundation, either version 3 of the License, or
+(at your option) any later version.
+
+GanttProject is distributed in the hope that it will be useful,
+but WITHOUT ANY WARRANTY; without even the implied warranty of
+MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+GNU General Public License for more details.
+
+You should have received a copy of the GNU General Public License
+along with GanttProject.  If not, see <http://www.gnu.org/licenses/>.
+*/
+package net.sourceforge.ganttproject.chart.gantt;
+
+import java.util.List;
+import java.util.Map;
+
+import net.sourceforge.ganttproject.GPLogger;
+import net.sourceforge.ganttproject.language.GanttLanguage;
+import net.sourceforge.ganttproject.task.Task;
+import net.sourceforge.ganttproject.task.TaskManager;
+import net.sourceforge.ganttproject.task.TaskManager.TaskBuilder;
+import net.sourceforge.ganttproject.task.dependency.TaskDependency;
+import net.sourceforge.ganttproject.task.dependency.TaskDependencyConstraint;
+import net.sourceforge.ganttproject.task.dependency.TaskDependencyException;
+
+import org.jdesktop.swingx.treetable.DefaultMutableTreeTableNode;
+
+import com.google.common.collect.Lists;
+import com.google.common.collect.Maps;
+
+/**
+ * Implements procedures for clipboard operations with tasks.
+ *
+ * @author dbarashev (Dmitry Barashev)
+ */
+public class ClipboardTaskProcessor {
+  private final TaskManager myTaskManager;
+
+  public ClipboardTaskProcessor(TaskManager taskManager) {
+    myTaskManager = taskManager;
+  }
+
+  public List<Task> paste(
+      Task selectedTask, List<DefaultMutableTreeTableNode> nodes, List<TaskDependency> deps) {
+    Task pasteRoot = myTaskManager.getTaskHierarchy().getContainer(selectedTask);
+    if (pasteRoot == null) {
+      pasteRoot = myTaskManager.getRootTask();
+      selectedTask = null;
+    }
+
+    List<Task> result = Lists.newArrayListWithExpectedSize(nodes.size());
+    Map<Task, Task> original2copy = Maps.newHashMap();
+    for (DefaultMutableTreeTableNode taskNode : nodes) {
+      Task task = (Task) taskNode.getUserObject();
+      Task copy = copyAndInsert(task, pasteRoot, selectedTask, original2copy);
+      result.add(copy);
+    }
+    copyDependencies(deps, original2copy);
+    return result;
+  }
+
+  private void copyDependencies(List<TaskDependency> deps, Map<Task, Task> original2copy) {
+    for (TaskDependency td : deps) {
+      Task dependee = td.getDependee();
+      Task dependant = td.getDependant();
+      TaskDependencyConstraint constraint = td.getConstraint();
+      try {
+        TaskDependency dep = myTaskManager.getDependencyCollection().createDependency(
+            original2copy.get(dependant),
+            original2copy.get(dependee),
+            myTaskManager.createConstraint(constraint.getType()));
+        dep.setDifference(td.getDifference());
+        dep.setHardness(td.getHardness());
+      } catch (TaskDependencyException e) {
+        GPLogger.log(e);
+      }
+    }
+  }
+
+  private Task copyAndInsert(Task task, Task newContainer, Task prevSibling, Map<Task, Task> original2copy) {
+    TaskBuilder builder = myTaskManager.newTaskBuilder().withPrototype(task).withParent(newContainer).withPrevSibling(prevSibling);
+    String newName = GanttLanguage.getInstance().formatText(
+        "task.copy.prefix", GanttLanguage.getInstance().getText("copy2"), task.getName());
+    builder = builder.withName(newName);
+    Task result = builder.build();
+    original2copy.put(task, result);
+    for (Task child : myTaskManager.getTaskHierarchy().getNestedTasks(task)) {
+      copyAndInsert(child, result, null, original2copy);
+    }
+    return result;
+  }
+}
diff --git a/ganttproject/src/net/sourceforge/ganttproject/task/TaskManager.java b/ganttproject/src/net/sourceforge/ganttproject/task/TaskManager.java
index 8af9e64..a7c7003 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/task/TaskManager.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/task/TaskManager.java
@@ -50,14 +50,15 @@ public interface TaskManager {
     TimeDuration myDuration;
     Color myColor;
     Task myPrevSibling;
-    boolean isExpanded;
+    Boolean isExpanded;
     Task myParent;
     boolean isLegacyMilestone;
     Date myEndDate;
     String myNotes;
     String myWebLink;
-    int myCompletion;
+    Integer myCompletion;
     Priority myPriority;
+    Task myPrototype;
 
     public TaskBuilder withColor(Color color) {
       myColor = color;
@@ -118,6 +119,11 @@ public interface TaskManager {
       return this;
     }
 
+    public TaskBuilder withPrototype(Task prototype) {
+      myPrototype = prototype;
+      return this;
+    }
+
     public TaskBuilder withStartDate(Date startDate) {
       myStartDate = startDate;
       return this;
diff --git a/ganttproject/src/net/sourceforge/ganttproject/task/TaskManagerImpl.java b/ganttproject/src/net/sourceforge/ganttproject/task/TaskManagerImpl.java
index fe02bf4..4f74517 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/task/TaskManagerImpl.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/task/TaskManagerImpl.java
@@ -295,7 +295,8 @@ public class TaskManagerImpl implements TaskManager {
           myId = getAndIncrementId();
         }
 
-        TaskImpl task = new GanttTask("", new GanttCalendar(), 1, TaskManagerImpl.this, myId);
+        TaskImpl task = myPrototype == null ?
+            new GanttTask("", new GanttCalendar(), 1, TaskManagerImpl.this, myId) : new GanttTask((TaskImpl)myPrototype);
 
         String name = myName == null ? getTaskNamePrefixOption().getValue() + "_" + task.getTaskID() : myName;
         task.setName(name);
@@ -318,10 +319,18 @@ public class TaskManagerImpl implements TaskManager {
         if (myPriority != null) {
           task.setPriority(myPriority);
         }
-        task.setExpand(isExpanded);
-        task.setNotes(myNotes);
-        task.setWebLink(myWebLink);
-        task.setCompletionPercentage(myCompletion);
+        if (isExpanded != null) {
+          task.setExpand(isExpanded);
+        }
+        if (myNotes != null) {
+          task.setNotes(myNotes);
+        }
+        if (myWebLink != null) {
+          task.setWebLink(myWebLink);
+        }
+        if (myCompletion != null) {
+          task.setCompletionPercentage(myCompletion);
+        }
         registerTask(task);
 
 
```
