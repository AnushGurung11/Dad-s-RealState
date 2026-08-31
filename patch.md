# Fixes I need

- So When i open the Show file Storage location option It show me all different applcition which are not related to the whole program. 
- I just want it to show the native file explorer place. 
- For storing the App data dont store it in the download folder, Keep it safe in app date and create a sepeate folder for LUCKY and there keep the data in data folder so that if client accedentlay deletes the files from download folder it remain safe. 
- First check if there is pre exisiting data in the download folder then move that to the App data fodler. 

# New Flow for Flat Creation and Cheque (Rent of the flat)
## Separating the flat creation to lease (Cheque details which is for rent payament of flat)

### Creating a flat
- Keep the following fields for creating a flat. 
- Flat name, address, Registered date (Date when the flat was registered not related to Cheque/ Lease payament of the flat just an info field).
- Registeration name (On Whose name was the flat registered under)
- Total number of beds (5-20 min and max value )
- Landline number, landline registered under name, Esewas number, Wifi name, wifi password

### Up on creating A flat
- I should be able to later edit all the information of flat. 
- Regarding the beds, Inside the flat, beds are displayed, there A plus sign should be present to add a bed and a delete button to delete a bed. 
- Regarding if deletion is trying to be done when a person is being assigned to that bed dont allow. For this type of scenario, a button to make the bed vacant must be present and this will update the status of Tenant as unassigned. 
- If instead i need to assign the person to another bed i should be able to do that as well by having an option to (assign to another bed ) where i can choose the availabe active flats with vacant bed and then vacant bed number to move the person to another bed assignment. 


### Flat Lease and Cheque payment
- Let this be a separate page for now which should be called Cheque Flats 
- In this page, First there should be a button for adding cheque details to flat. 
- This Adding cheque details must only applicabe to those flats whose cheque details are not assigned. 
- In this, active flats with no checque details must be displayed for selection. 
- After selection I need to fill details like, Default amount to pay each time.
- Repeate after months (This field means after a payemnt next payament will be after how many months)
- Select a date (selecting a date for Payemnt) eg, i set recurring months to be 1 and date to 20. Meaning after payament, next payment will be next month at 20 default.
- So after creation of cheque details, the page must now display FLat name, Time remaining for next payemnt, Amount to pay and edit option for editing any field of the cheque detail. 
- In the page, There must be a custom button for pay. 
- After clicking pay button, I should be able to select the flat cheque i want to pay, method of payemnt (card, cash, cheque, Online, Other), Description, Amount (It should show the default amount set during scheque creation but we must be able to edit as well), date of payemnt 
- Then a Done option to Confirm the payemnt. 
- Now the payemnt is done. For checking the payemnt history, In the same page of cheque. I click the flat and inside there there shold be all the records of payemnt made. 
- Beside each transiction there must be a edit option and delete option. Edit must allow us to edit any fileds filled while paying the cheque. 

