# GanttProject Bug [817](https://github.com/bardsoftware/ganttproject/issues/817)


## Patch

```
commit 5776fd22035b90304ad9a9864814fc50d9a54165
Author: dbarashev <dbarashev@localhost>
Date:   Mon Jan 27 03:29:28 2014 +0400

    fixes issue #817
    We will also indicate invalid/empty values with red background

diff --git a/ganttproject/src/net/sourceforge/ganttproject/gui/UIUtil.java b/ganttproject/src/net/sourceforge/ganttproject/gui/UIUtil.java
index 3d07b44..6f21e71 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/gui/UIUtil.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/gui/UIUtil.java
@@ -30,6 +30,7 @@ import java.awt.event.FocusAdapter;
 import java.awt.event.FocusEvent;
 import java.text.ParseException;
 import java.util.Arrays;
+import java.util.Date;
 
 import javax.swing.Action;
 import javax.swing.BorderFactory;
@@ -37,14 +38,18 @@ import javax.swing.Box;
 import javax.swing.ImageIcon;
 import javax.swing.JButton;
 import javax.swing.JComponent;
+import javax.swing.JFormattedTextField;
 import javax.swing.JMenu;
 import javax.swing.JMenuItem;
 import javax.swing.JPanel;
 import javax.swing.JTable;
+import javax.swing.JTextField;
 import javax.swing.KeyStroke;
 import javax.swing.SwingUtilities;
 import javax.swing.UIManager;
 import javax.swing.border.Border;
+import javax.swing.event.DocumentEvent;
+import javax.swing.event.DocumentListener;
 import javax.swing.table.TableCellRenderer;
 import javax.swing.table.TableColumn;
 
@@ -55,10 +60,17 @@ import org.jdesktop.swingx.decorator.ComponentAdapter;
 import org.jdesktop.swingx.decorator.HighlightPredicate;
 import org.jdesktop.swingx.decorator.Highlighter;
 import org.jdesktop.swingx.decorator.HighlighterFactory;
+
+import biz.ganttproject.core.option.GPOption;
+import biz.ganttproject.core.option.ValidationException;
+
 import com.google.common.base.Predicate;
+import com.google.common.base.Strings;
 import com.google.common.collect.Lists;
 
 import net.sourceforge.ganttproject.action.GPAction;
+import net.sourceforge.ganttproject.gui.options.OptionsPageBuilder;
+import net.sourceforge.ganttproject.gui.options.OptionsPageBuilder.ValueValidator;
 import net.sourceforge.ganttproject.language.GanttLanguage;
 
 public abstract class UIUtil {
@@ -70,6 +82,7 @@ public abstract class UIUtil {
   }, new Color(0xf0, 0xf0, 0xe0), null);
 
   public static final Color ERROR_BACKGROUND = new Color(255, 191, 207);
+  public static final Color INVALID_FIELD_COLOR = Color.RED.brighter();
 
   static {
     ImageIcon calendarImage = new ImageIcon(UIUtil.class.getResource("/icons/calendar_16.gif"));
@@ -160,6 +173,42 @@ public abstract class UIUtil {
     setupTableUI(table, 10);
   }
 
+  public static <T> DocumentListener attachValidator(final JTextField textField, final OptionsPageBuilder.ValueValidator<T> validator, final GPOption<T> option) {
+    final DocumentListener listener = new DocumentListener() {
+      private void saveValue() {
+        try {
+          T value = validator.parse(textField.getText());
+          if (option != null) {
+            option.setValue(value);
+          }
+          textField.setBackground(getValidFieldColor());
+        }
+        /* If value in text filed is not integer change field color */
+        catch (NumberFormatException ex) {
+          textField.setBackground(INVALID_FIELD_COLOR);
+        } catch (ValidationException ex) {
+          textField.setBackground(INVALID_FIELD_COLOR);
+        }
+      }
+
+      @Override
+      public void insertUpdate(DocumentEvent e) {
+        saveValue();
+      }
+
+      @Override
+      public void removeUpdate(DocumentEvent e) {
+        saveValue();
+      }
+
+      @Override
+      public void changedUpdate(DocumentEvent e) {
+        saveValue();
+      }
+    };
+    textField.getDocument().addDocumentListener(listener);
+    return listener;
+  }
   /**
    * @return a {@link JXDatePicker} component with the default locale, images
    *         and date formats.
@@ -168,19 +217,41 @@ public abstract class UIUtil {
     final JXDatePicker result = new JXDatePicker();
     result.setLocale(GanttLanguage.getInstance().getDateFormatLocale());
     result.addActionListener(listener);
-
-    result.getEditor().addFocusListener(new FocusAdapter() {
+    final JFormattedTextField editor = result.getEditor();
+    final ValueValidator<Boolean> validator = new ValueValidator<Boolean>() {
+      @Override
+      public Boolean parse(String text) throws ValidationException {
+        if (Strings.isNullOrEmpty(text)) {
+          throw new ValidationException();
+        }
+        try {
+          if (GanttLanguage.getInstance().getLongDateFormat().parse(text) == null
+              && GanttLanguage.getInstance().getShortDateFormat().parse(text) == null) {
+            throw new ValidationException("Can't parse value=" + text + "as date");
+          }
+          return true;
+        } catch (ParseException e) {
+          throw new ValidationException("Can't parse value=" + text + "as date", e);
+        }
+      }
+    };
+    UIUtil.attachValidator(editor, validator, null);
+    editor.addFocusListener(new FocusAdapter() {
       @Override
       public void focusLost(FocusEvent e) {
         try {
-          if (result.getEditor().getValue() != null) {
+          if ((editor.getValue() instanceof Date) || validator.parse(String.valueOf(editor.getValue()))) {
+            editor.setBackground(getValidFieldColor());
             result.commitEdit();
             listener.actionPerformed(new ActionEvent(result, ActionEvent.ACTION_PERFORMED, ""));
+            return;
           }
-        } catch (ParseException e1) {
-          // TODO Auto-generated catch block
-          e1.printStackTrace();
+        } catch (ValidationException e1) {
+          // We probably don't want to log parse/validation exceptions
+        } catch (ParseException e2) {
+          // We probably don't want to log parse/validation exceptions
         }
+        editor.setBackground(INVALID_FIELD_COLOR);
       }
     });
     result.setFormats(GanttLanguage.getInstance().getLongDateFormat(), GanttLanguage.getInstance().getShortDateFormat());
@@ -263,4 +334,9 @@ public abstract class UIUtil {
     result.setToolTipText(null);
     return result;
   }
+
+  public static Color getValidFieldColor() {
+    return UIManager.getColor("TextField.background");
+  }
+
 }
diff --git a/ganttproject/src/net/sourceforge/ganttproject/gui/options/OptionsPageBuilder.java b/ganttproject/src/net/sourceforge/ganttproject/gui/options/OptionsPageBuilder.java
index 69455bb..7737565 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/gui/options/OptionsPageBuilder.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/gui/options/OptionsPageBuilder.java
@@ -71,7 +71,6 @@ import com.google.common.base.Function;
  * @author bard
  */
 public class OptionsPageBuilder {
-  private static final Color INVALID_FIELD_COLOR = Color.RED.brighter();
   I18N myi18n = new I18N();
   private Component myParentComponent;
   private final LayoutApi myLayoutApi;
@@ -271,14 +270,14 @@ public class OptionsPageBuilder {
     } else if (option instanceof StringOption) {
       result = createStringComponent((StringOption) option);
     } else if (option instanceof IntegerOption) {
-      result = createNumericComponent((IntegerOption) option, new NumericParser<Integer>() {
+      result = createValidatingComponent((IntegerOption) option, new ValueValidator<Integer>() {
         @Override
         public Integer parse(String text) {
           return Integer.valueOf(text);
         }
       });
     } else if (option instanceof DoubleOption) {
-      result = createNumericComponent((DoubleOption) option, new NumericParser<Double>() {
+      result = createValidatingComponent((DoubleOption) option, new ValueValidator<Double>() {
         @Override
         public Double parse(String text) {
           return Double.valueOf(text);
@@ -302,8 +301,8 @@ public class OptionsPageBuilder {
     return result;
   }
 
-  private Color getValidFieldColor() {
-    return UIManager.getColor("TextField.background");
+  private static Color getValidFieldColor() {
+    return UIUtil.getValidFieldColor();
   }
 
   private static void updateTextField(final JTextField textField, final DocumentListener listener,
@@ -348,7 +347,7 @@ public class OptionsPageBuilder {
           option.setValue(result.getText());
           result.setBackground(getValidFieldColor());
         } catch (ValidationException ex) {
-          result.setBackground(INVALID_FIELD_COLOR);
+          result.setBackground(UIUtil.INVALID_FIELD_COLOR);
         }
       }
 
@@ -576,8 +575,8 @@ public class OptionsPageBuilder {
     return result;
   }
 
-  private interface NumericParser<T extends Number> {
-    T parse(String text) throws NumberFormatException;
+  public interface ValueValidator<T> {
+    T parse(String text) throws ValidationException;
   }
 
   /**
@@ -587,39 +586,9 @@ public class OptionsPageBuilder {
    * @param option
    * @return
    */
-  private <T extends Number> Component createNumericComponent(final GPOption<T> option, final NumericParser<T> parser) {
+  public static <T extends Number> Component createValidatingComponent(final GPOption<T> option, final ValueValidator<T> parser) {
     final JTextField result = new JTextField(String.valueOf(option.getValue()));
-    final DocumentListener listener = new DocumentListener() {
-      private void saveValue() {
-        try {
-          T value = parser.parse(result.getText());
-          option.setValue(value);
-          result.setBackground(getValidFieldColor());
-        }
-        /* If value in text filed is not integer change field color */
-        catch (NumberFormatException ex) {
-          result.setBackground(INVALID_FIELD_COLOR);
-        } catch (ValidationException ex) {
-          result.setBackground(INVALID_FIELD_COLOR);
-        }
-      }
-
-      @Override
-      public void insertUpdate(DocumentEvent e) {
-        saveValue();
-      }
-
-      @Override
-      public void removeUpdate(DocumentEvent e) {
-        saveValue();
-      }
-
-      @Override
-      public void changedUpdate(DocumentEvent e) {
-        saveValue();
-      }
-    };
-    result.getDocument().addDocumentListener(listener);
+    final DocumentListener listener = UIUtil.attachValidator(result, parser, option);
     option.addChangeValueListener(new ChangeValueListener() {
       @Override
       public void changeValue(final ChangeValueEvent event) {
diff --git a/ganttproject/src/net/sourceforge/ganttproject/gui/taskproperties/TaskScheduleDatesPanel.java b/ganttproject/src/net/sourceforge/ganttproject/gui/taskproperties/TaskScheduleDatesPanel.java
index 69f5bde..c037c63 100644
--- a/ganttproject/src/net/sourceforge/ganttproject/gui/taskproperties/TaskScheduleDatesPanel.java
+++ b/ganttproject/src/net/sourceforge/ganttproject/gui/taskproperties/TaskScheduleDatesPanel.java
@@ -23,8 +23,10 @@ import java.awt.event.ActionEvent;
 import java.awt.event.ActionListener;
 import java.awt.event.FocusEvent;
 import java.awt.event.FocusListener;
+import java.text.ParseException;
 import java.util.Arrays;
 import java.util.Calendar;
+import java.util.Date;
 import java.util.List;
 
 import javax.swing.Action;
@@ -147,7 +149,10 @@ public class TaskScheduleDatesPanel {
     myStartDatePicker = UIUtil.createDatePicker(new ActionListener() {
       @Override
       public void actionPerformed(ActionEvent e) {
-        setStart(CalendarFactory.createGanttCalendar(((JXDatePicker) e.getSource()).getDate()), true);
+        Date date = ((JXDatePicker) e.getSource()).getDate();
+        if (date != null) {
+          setStart(CalendarFactory.createGanttCalendar(date), true);
+        }
       }
     });
     final GPAction startDateLockAction = createLockAction("option.taskProperties.main.scheduling.manual.value.start", ourStartDateLock);
```
