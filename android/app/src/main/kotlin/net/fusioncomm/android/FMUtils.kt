package net.fusioncomm.android

import org.linphone.core.Address
import org.linphone.core.Call

class FMUtils {
    companion object {
        fun getDisplayName(address: Address?): String {
            if (address == null) return "[null]"
            if (address.displayName == null) {
                val account = FMCore.core.accountList.find { account ->
                    account.params.identityAddress?.asStringUriOnly() == address.asStringUriOnly()
                }
                val localDisplayName = account?.params?.identityAddress?.displayName
                // Do not return an empty local display name
                if (!localDisplayName.isNullOrEmpty()) {
                    return localDisplayName
                }
            }
            // Do not return an empty display name
            return address.displayName ?: address.username ?: address.asString()
        }

        fun getPhoneNumber(address: Address?): String {
            if(address == null) return ""
            val cleanSip: String = address.asStringUriOnly().replace("sip:", "")
            return cleanSip.substring(0, cleanSip.indexOf("@"))
        }

    }
}