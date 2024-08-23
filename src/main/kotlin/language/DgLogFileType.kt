package lb.bormental.language

import com.intellij.openapi.fileTypes.LanguageFileType
import javax.swing.Icon

object DgLogFileType : LanguageFileType(DgLogLanguage) {

    override fun getName(): String = "DataGripDiagnosticLog"

    override fun getDescription(): String = "DataGrip diagnostic log"

    override fun getDefaultExtension(): String = "dlog"

    override fun getIcon(): Icon = DgLogLanguageIcons.DgLogFileIcon

}