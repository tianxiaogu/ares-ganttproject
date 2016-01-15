# GanttProject Bug [465]()


## Patch

```
commit b090a730b19c7aed5ab7fe0687231004fff9f6eb
Author: dbarashev <dbarashev@localhost>
Date:   Sat Mar 31 01:13:30 2012 +0400

    fixes issue #465

diff --git a/ganttproject/src/net/sourceforge/ganttproject/GPTreeTableBase.java b/ganttproject/src/net/sourceforge/ganttproject/GPTreeTableBase.java
index dc11ae3..73d49e2 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/GPTreeTableBase.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/GPTreeTableBase.java
@@ -102,8 +102,14 @@ public abstract class GPTreeTableBase extends JNTreeTable implements CustomPrope
     @Override
     public void actionPerformed(ActionEvent e) {
       JTable t = getTable();
-      TreeTableCellEditorImpl cellEditor = (TreeTableCellEditorImpl) getTable().getCellEditor(t.getSelectedRow(),
-          t.getSelectedColumn());
+      if (t.getSelectedRow() < 0) {
+        return;
+      }
+      if (t.getSelectedColumn() < 0) {
+        t.getColumnModel().getSelectionModel().setSelectionInterval(0, 0);
+      }
+      TreeTableCellEditorImpl cellEditor = (TreeTableCellEditorImpl) getTable().getCellEditor(
+          t.getSelectedRow(), t.getSelectedColumn());
       t.editCellAt(t.getSelectedRow(), t.getSelectedColumn());
       cellEditor.requestFocus();
     }
```
