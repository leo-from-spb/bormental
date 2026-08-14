package lb.bormental.plugin

import com.intellij.openapi.project.DumbAware
import com.intellij.openapi.project.Project
import com.intellij.openapi.wm.ToolWindow
import com.intellij.openapi.wm.ToolWindowFactory
import com.intellij.ui.components.JBLabel
import com.intellij.ui.content.ContentFactory
import com.intellij.util.ui.JBUI
import lb.bormental.core.LogFile
import javax.swing.JComponent
import javax.swing.JPanel

/**
 * The place where log files will be shown. For now it just proves that the plugin is loaded.
 */
internal class BormentalToolWindowFactory : ToolWindowFactory, DumbAware {

    override fun createToolWindowContent(project: Project, toolWindow: ToolWindow) {
        val content = ContentFactory.getInstance().createContent(createPanel(), null, false)
        toolWindow.contentManager.addContent(content)
    }

    private fun createPanel(): JComponent {
        val panel = JPanel()
        panel.border = JBUI.Borders.empty(12)
        panel.add(JBLabel(describe(LogFile.EMPTY)))
        return panel
    }

    private fun describe(log: LogFile): String =
        if (log.isEmpty) "Dr. Bormental is here. No log opened yet."
        else "${log.lines.size} lines."
}
