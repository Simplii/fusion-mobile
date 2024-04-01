package net.fusioncomm.android

import android.annotation.SuppressLint
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.SharedPreferences
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.telephony.PhoneNumberUtils
import android.util.Log
import androidx.loader.content.CursorLoader
import com.google.gson.Gson
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream
import java.util.Calendar

@SuppressLint("Range")
class ContactsThread (private var channel: MethodChannel, private var contentResolver: ContentResolver, private var context: Context): Thread() {
    private val gson = Gson()
    private val displayNameCol: String = ContactsContract.Contacts.DISPLAY_NAME_PRIMARY
    private val sharedPref: SharedPreferences = context.getSharedPreferences(
        "net.fusioncomm.android.fusionValues",
        Context.MODE_PRIVATE
    )
    override fun run() {
        val contacts: List<Map<String,Any?>> = getContacts()
        Handler(Looper.getMainLooper()).post {
            channel.invokeMethod("CONTACTS_LOADED",gson.toJson(contacts))
            with(sharedPref.edit()) {
                putString("contacts_last_sync", Calendar.getInstance().timeInMillis.toString())
                apply()
            }
        }
    }


    fun syncNew(){
        val lastSync = sharedPref.getString("contacts_last_sync", "")
        with(sharedPref.edit()) {
            putString("contacts_last_sync", Calendar.getInstance().timeInMillis.toString())
            apply()
        }
        try {
            val projection = arrayOf(
                ContactsContract.Contacts.DISPLAY_NAME_PRIMARY,
                ContactsContract.Contacts.HAS_PHONE_NUMBER,
                ContactsContract.Contacts._ID
            )
            val selection = "${ContactsContract.Contacts.CONTACT_LAST_UPDATED_TIMESTAMP} >= ?"
            val selectionArgs = arrayOf(lastSync)
            val contacts:MutableList<Map<String,Any?>> = mutableListOf()
            contentResolver.query(
                ContactsContract.Contacts.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                null
            )?.use {
                val idCol = it.getColumnIndex(ContactsContract.Contacts._ID)

                while (it.moveToNext()){
                    val contactId = it.getString(idCol)
                    val phoneNumbersArray = getContactPhoneNumbers(contactId)
                    if(phoneNumbersArray.isEmpty()){
                        it.close()
                        continue
                    }
                    val (firstName, lastName, name) = getContactStructuredName(contactId)
                    val (company, jobTitle) = getCompanyInfo(contactId)
                    val image: ByteArray? = getDisplayPhoto(
                        it.getLong(idCol)
                    )

                    val emailsArray = getContactEmails(contactId)
                    val addressesArray = getContactAddresses(contactId)
                    val contactObj = mapOf<String,Any?>(
                        Pair("id",contactId),
                        Pair("name", name),
                        Pair("firstName", firstName),
                        Pair("lastName", lastName),
                        Pair("phoneNumbers", phoneNumbersArray),
                        Pair("emails", emailsArray),
                        Pair("addresses", addressesArray),
                        Pair("profileImage", image),
                        Pair("company", company),
                        Pair("jobTitle", jobTitle)
                    )
//                Log.d("MDBM", "contactObj ${gson.toJson(contactObj)}")
                    contacts.add(contactObj)
                }
            }
            Log.d("MDBM Contacts", "${contacts.size}")
            Handler(Looper.getMainLooper()).post {
                channel.invokeMethod("CONTACTS_SYNCED",gson.toJson(contacts))
            }

        } catch (e: IllegalStateException) {
            Log.e("MDBM Contacts", "${e.message}")
        }
    }

    private fun getContacts() : List<Map<String,Any?>>{
        val cursor: Cursor? = contentResolver.query(
                ContactsContract.Contacts.CONTENT_URI,
                null,
                null,
                null,
                null
        )
        val contacts:MutableList<Map<String,Any?>> = mutableListOf()

        if(cursor != null && cursor.count > 0){
            while (cursor.moveToNext()){
                val contactId: String = cursor.getString(
                        cursor.getColumnIndex(
                                ContactsContract.Contacts._ID
                        )
                )
                val phoneNumbersArray = getContactPhoneNumbers(contactId)
                if(phoneNumbersArray.isEmpty()){
                    continue
                }
                val (firstName, lastName, name) = getContactStructuredName(contactId)
                val (company, jobTitle) = getCompanyInfo(contactId)
                val image: ByteArray? = getDisplayPhoto(
                        cursor.getLong(
                                cursor.getColumnIndex(
                                        ContactsContract.Contacts._ID
                                )
                        )
                )

                val emailsArray = getContactEmails(contactId)
                val addressesArray = getContactAddresses(contactId)
                val contactObj = mapOf<String,Any?>(
                    Pair("id",contactId),
                    Pair("name", name),
                    Pair("firstName", firstName),
                    Pair("lastName", lastName),
                    Pair("phoneNumbers", phoneNumbersArray),
                    Pair("emails", emailsArray),
                    Pair("addresses", addressesArray),
                    Pair("profileImage", image),
                    Pair("company", company),
                    Pair("jobTitle", jobTitle)
                )
//                Log.d("MDBM", "contactObj ${gson.toJson(contactObj)}")
                contacts.add(contactObj)
            }
            cursor.close()
        }
        return contacts
    }

    private fun getContactPhoneNumbers (contactId:String): Array<Map<String,Any>> {
        val phoneNumbers:MutableList<Map<String,Any>> = mutableListOf()

        val contactPhoneCursor: Cursor? = contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                null,
                ContactsContract.CommonDataKinds.Phone.CONTACT_ID + "=" + contactId,
                null,
                null
        )
        val contactPhoneNumber = mutableMapOf<String,Any>()
        if(contactPhoneCursor != null && contactPhoneCursor.count > 0){
            while (contactPhoneCursor.moveToNext()){
                val phoneNumber:String = contactPhoneCursor.getString(
                        contactPhoneCursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER
                        )
                )

                val phoneType:Int = contactPhoneCursor.getInt(
                        contactPhoneCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.Phone.TYPE
                        )
                )
                val number:String = PhoneNumberUtils.normalizeNumber(phoneNumber)

                if(!contactPhoneNumber.containsKey(number)){
                    contactPhoneNumber[number] = getPhoneNumberType(phoneType)
                    phoneNumbers.add(
                            mapOf(
                                    Pair("type", getPhoneNumberType(phoneType)),
                                    Pair("number", PhoneNumberUtils.normalizeNumber(phoneNumber)),
                                    Pair("z", getPhoneNumberType(phoneType) == "mobile"),
                            )
                    )
                } else if(contactPhoneNumber.containsKey(number) &&
                        contactPhoneNumber[number] != getPhoneNumberType(phoneType)){
                    phoneNumbers.add(
                            mapOf(
                                    Pair("type", getPhoneNumberType(phoneType)),
                                    Pair("number", PhoneNumberUtils.normalizeNumber(phoneNumber)),
                                    Pair("smsCapable", getPhoneNumberType(phoneType) == "mobile"),
                            )
                    )
                }
            }
            contactPhoneCursor.close()
        }
        return phoneNumbers.toTypedArray()
    }

    private fun getContactStructuredName (contactId:String): Triple<String, String, String> {
        var firstName = ""
        var lastName = ""
        var name = ""
        var middle = ""


        val selection = ContactsContract.Data.MIMETYPE + " = ? AND " +
                ContactsContract.CommonDataKinds.StructuredName.CONTACT_ID + " = ?"

        val selectionArgs = arrayOf(
                ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE,
                contactId
        )

        val structuredNameCursor: Cursor? = contentResolver.query(
                ContactsContract.Data.CONTENT_URI,
                null,
                selection,
                selectionArgs,
                null
        )
        if(structuredNameCursor != null && structuredNameCursor.count > 0){
            while (structuredNameCursor.moveToNext()){
                val given:String? = structuredNameCursor.getString(
                        structuredNameCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME
                        )
                )
                val family:String? = structuredNameCursor.getString(
                        structuredNameCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME
                        )
                )
                val middleName:String? = structuredNameCursor.getString(
                        structuredNameCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.StructuredName.MIDDLE_NAME
                        )
                )
                val display:String? = structuredNameCursor.getString(
                        structuredNameCursor.getColumnIndex(displayNameCol)
                )
                firstName = given ?: ""
                lastName = family ?: ""
                name = display ?: ""
                middle = middleName ?: ""

                if(firstName.isEmpty() && name.isNotEmpty()){
                    firstName = name.split(" ")[0]
                }
                if(firstName.isNotEmpty() &&
                        firstName.trim() == name.trim() && name.split(" ").count() > 1){
                    // sanitize first name
                    firstName = name.split(" ")[0]
                }
                if(lastName.isEmpty() && name.isNotEmpty() && name.split(" ").count() > 1){
                    lastName = name.split(" ")[1]
                }
                if(middle.isNotEmpty()) {
                    lastName = "$middle $lastName"
                }
            }
            structuredNameCursor.close()
        }
        return Triple(firstName,lastName,name)
    }

    private fun getContactEmails (contactId:String): Array<Map<String,Any>> {
        //something wrong here
        val phoneEmails:MutableList<Map<String,Any>> = mutableListOf()

        val contactEmailCursor: Cursor? = contentResolver.query(
                ContactsContract.CommonDataKinds.Email.CONTENT_URI,
                null,
                ContactsContract.CommonDataKinds.Email.CONTACT_ID + "=" + contactId,
                null,
                null
        )
        if(contactEmailCursor != null && contactEmailCursor.count > 0){
            while (contactEmailCursor.moveToNext()){
                val email:String = contactEmailCursor.getString(
                        contactEmailCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.Email.ADDRESS
                        )
                )
                val emailType:Int = contactEmailCursor.getInt(
                        contactEmailCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.Email.TYPE
                        )
                )
                val emailId:String = contactEmailCursor.getString(
                        contactEmailCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.Email._ID
                        )
                )
//                getContactAddresses(contactId)
                phoneEmails.add(
                        mapOf(
                                Pair("type", getEmailType(emailType)),
                                Pair("email", email),
                                Pair("id", emailId)
                        )
                )
            }
            contactEmailCursor.close()
        }
        return phoneEmails.toTypedArray()
    }

    private fun getContactAddresses (contactId:String): Array<Map<String,Any>> {
        val addresses:MutableList<Map<String,Any>> = mutableListOf()
        val addressesCursor: Cursor? = contentResolver.query(
                ContactsContract.CommonDataKinds.StructuredPostal.CONTENT_URI,
                null,
                ContactsContract.CommonDataKinds.StructuredPostal.CONTACT_ID + "=" + contactId,
                null,
                null
        )
        if(addressesCursor != null && addressesCursor.count > 0){
            while (addressesCursor.moveToNext()){
                val formattedAddress:String = addressesCursor.getString(
                        addressesCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.StructuredPostal.FORMATTED_ADDRESS
                        )
                )
                val street:String? = addressesCursor.getString(
                        addressesCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.StructuredPostal.STREET
                        )
                )
                val city:String? = addressesCursor.getString(
                        addressesCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.StructuredPostal.CITY
                        )
                )
                val state:String? = addressesCursor.getString(
                        addressesCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.StructuredPostal.REGION
                        )
                )
                val zip:String? = addressesCursor.getString(
                        addressesCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.StructuredPostal.POSTCODE
                        )
                )
                val country:String? = addressesCursor.getString(
                        addressesCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.StructuredPostal.COUNTRY
                        )
                )
                val addressType:Int = addressesCursor.getInt(
                        addressesCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.StructuredPostal.TYPE
                        )
                )


                addresses.add(
                        mapOf(
                                Pair("address1", street ?: ""),
                                Pair("address2", ""),
                                Pair("city", city ?: ""),
                                Pair("state", state ?: ""),
                                Pair("zip", zip ?: ""),
                                Pair("country", country ?: ""),
                                Pair("type", addressType),
                                Pair("formattedAddress", formattedAddress)
                        )
                )

            }
            addressesCursor.close()
        }
        return addresses.toTypedArray()
    }

//    private fun getProfileImage(contactId: Long): ByteArray? {
//        val contactUri = ContentUris.withAppendedId(
//                ContactsContract.Contacts.CONTENT_URI,
//                contactId
//        )
//        val photoUri = Uri.withAppendedPath(
//                contactUri,
//                ContactsContract.Contacts.Photo.CONTENT_DIRECTORY
//        )
//        val cursor: Cursor = contentResolver.query(
//                photoUri,
//                arrayOf<String>(ContactsContract.Contacts.Photo.PHOTO),
//                null,
//                null,
//                null
//        ) ?: return null
//        cursor.use { cursor ->
//            if (cursor.moveToFirst()) {
//                val data = cursor.getBlob(0)
//                if (data != null) {
//                    return data
//                }
//            }
//        }
//        return null
//    }

    private fun getDisplayPhoto(contactId: Long): ByteArray? {
        val contactUri = ContentUris.withAppendedId(ContactsContract.Contacts.CONTENT_URI, contactId)
        val displayPhotoUri = Uri.withAppendedPath(contactUri, ContactsContract.Contacts.Photo.DISPLAY_PHOTO)
        return try {
            val fd: AssetFileDescriptor? = contentResolver.openAssetFileDescriptor(displayPhotoUri, "r")
            val st: InputStream? = fd?.createInputStream()
            st?.readBytes()
        } catch (e: IOException) {
            null
        }
    }

    private fun getCompanyInfo(contactId: String): Pair<String, String>  {
        val selection = ContactsContract.Data.MIMETYPE + " = ? AND " +
                ContactsContract.CommonDataKinds.Organization.CONTACT_ID + " = ?"

        val selectionArgs = arrayOf(
                ContactsContract.CommonDataKinds.Organization.CONTENT_ITEM_TYPE,
                contactId
        )
        var companyName = ""
        var jobTitle = ""
        val contactCompanyCursor: Cursor? = contentResolver.query(
                ContactsContract.Data.CONTENT_URI,
                null,
                selection,
                selectionArgs,
                null
        )
        if(contactCompanyCursor != null && contactCompanyCursor.count > 0){
            while (contactCompanyCursor.moveToNext()){
                val company:String? = contactCompanyCursor.getString(
                        contactCompanyCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.Organization.COMPANY
                        )
                )
                val title:String? = contactCompanyCursor.getString(
                        contactCompanyCursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.Organization.TITLE
                        )
                )
                companyName = company ?: ""
                jobTitle = title ?: ""
            }
            contactCompanyCursor.close()
        }
        return Pair(companyName,jobTitle)
    }

    private fun getPhoneNumberType (phoneType:Int):String {
        var phoneNumberType = "other"
        if(phoneType == ContactsContract.CommonDataKinds.Phone.TYPE_HOME){
            phoneNumberType = "phone"
        }
        if(phoneType == ContactsContract.CommonDataKinds.Phone.TYPE_WORK){
            phoneNumberType = "work"
        }
        if(phoneType == ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE){
            phoneNumberType = "mobile"
        }
        if(phoneType == ContactsContract.CommonDataKinds.Phone.TYPE_MAIN){
            phoneNumberType = "phone"
        }
        return phoneNumberType
    }

    private fun getEmailType (phoneType:Int):String {
        var emailType = "personal"
        if(phoneType == ContactsContract.CommonDataKinds.Email.TYPE_WORK){
            emailType = "work"
        }
        return emailType
    }
}