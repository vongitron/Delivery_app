import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_seller_app/mainscreen/home_screen.dart';
import 'package:delivery_seller_app/widgets/custom_text_field.dart';
import 'package:delivery_seller_app/widgets/error_dialog.dart';
import 'package:delivery_seller_app/widgets/loading_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as fStorage;
import 'package:shared_preferences/shared_preferences.dart';

import '../global/global_page.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

// Form()
final GlobalKey<FormState> _formkey = GlobalKey<FormState>();

// Controller for register_form
TextEditingController nameController = TextEditingController();
TextEditingController emailController = TextEditingController();
TextEditingController passwordController = TextEditingController();
TextEditingController confirmPasswordController = TextEditingController();
TextEditingController phoneController = TextEditingController();
TextEditingController locationController = TextEditingController();

// To get an image from seller side
XFile? imageXFile;
final ImagePicker _picker = ImagePicker();

//Get image from local seller registration
Future<void> _getImage() async {
  imageXFile = await _picker.pickImage(source: ImageSource.gallery);
  setState(() {
    imageXFile;
  });
}

void setState(Null Function() param0) {
}


  // Location
  Position? position;
  List<Placemark>? placeMarks;

  String sellerImageUrl = "";
  String completeAddress = "";

  // Get current location
  getCurrentLocation() async
  {
  Position newPosition = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  position = newPosition;

  placeMarks = await placemarkFromCoordinates(
    position!.latitude,
    position!.longitude,
    localeIdentifier: "en"
  );

  Placemark pMark = placeMarks![0];

  String completeAddress = '${pMark.subThoroughfare} ${pMark.thoroughfare}, ${pMark.subLocality} ${pMark.locality}, ${pMark.subAdministrativeArea}, ${pMark.administrativeArea} ${pMark.postalCode}, ${pMark.country}';

  locationController.text = completeAddress;

}

Future<void> formValidation(BuildContext context) async
{
  if(imageXFile == null)
  {
    showDialog(
      context: context,
      builder: (c)
      {
        return ErrorDialog(
          message:"Please select an image.",
        );
      }
    );
  }
  else
  {
    if(passwordController.text == confirmPasswordController.text)
    {
      if(nameController.text.isNotEmpty && emailController.text.isNotEmpty && confirmPasswordController.text.isNotEmpty && phoneController.text.isNotEmpty && locationController.text.isNotEmpty)
      {
        //start uploading image
        showDialog(
          context: context,
          builder: (c)
          {
            return LoadingDialog(
              message: "",
            );
          }
        );

        // Save info to firestore
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        fStorage.Reference reference = fStorage.FirebaseStorage.instance.ref().child("sellers").child(fileName);
        fStorage.UploadTask uploadTask = reference.putFile(File(imageXFile!.path));
        fStorage.TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() {});
        await taskSnapshot.ref.getDownloadURL().then((url) {
          sellerImageUrl = url;

          authenticateSellerAndSignup(context);

        }
        );

      }
      else
      {
        showDialog(
          context: context,
          builder: (c)
          {
            return ErrorDialog(
              message: "Please write the complete required information for registration.",
            );
          }
        );
      }
    }
    else
    {
      showDialog(
        context: context,
        builder: (c)
        {
          return ErrorDialog(
            message: "Password do not match.",
          );
        }
      );
    }
  }
}

  void authenticateSellerAndSignup(BuildContext context) async
  {
    User? currentUser;
    
    await firebaseAuth.createUserWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    ).then((auth)
    {
      currentUser = auth.user;
    }
    ).catchError((error)
    {
      Navigator.pop(context);
      showDialog(
          context: context,
          builder: (c)
          {
          return ErrorDialog(
            message: error.message.toString(),
          );
          });
    });

    if(currentUser != null)
    {
      saveDataToFirestore(currentUser!).then((value)
      {
        Navigator.pop(context);
        // Send user to homepage
        Route newRoute = MaterialPageRoute(builder: (c) => HomeScreen());
        Navigator.pushReplacement(context, newRoute);

      }
      );
    }
  }

  Future saveDataToFirestore(User currentUser) async
  {
    FirebaseFirestore.instance.collection("sellers").doc(currentUser.uid).set({
      "sellerUID": currentUser.uid,
      "sellerEmail": currentUser.email,
      "sellerName": nameController.text.trim(),
      "sellerAvatarUrl": sellerImageUrl,
      "phone": phoneController.text.trim(),
      "address": completeAddress,
      "status": "approved",
      "earnings": 0.0,
      "lat": position!.latitude,
      "lng": position!.longitude,

    });

    // save data locally
    sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences!.setString("uid", currentUser.uid);
    await sharedPreferences!.setString("email", currentUser.email.toString());
    await sharedPreferences!.setString("name", nameController.text.trim());
    await sharedPreferences!.setString("photoUrl", sellerImageUrl);
  }


class _RegisterScreenState extends State<RegisterScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            const SizedBox(
              height: 10,
            ),
            InkWell(
              onTap: () {
                _getImage();
              },
              child: CircleAvatar(
                radius: MediaQuery.of(context).size.width * 0.20,
                backgroundColor: Colors.white,
                backgroundImage: imageXFile == null
                    ? null
                    : FileImage(
                        File(imageXFile!.path),
                      ),
                child: imageXFile == null
                    ? Icon(
                        Icons.add_photo_alternate,
                        size: MediaQuery.of(context).size.width * .20,
                        color: Colors.grey,
                      )
                    : null,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Form(
              key: _formkey,
              child: Column(
                children: [
                  CustomTextField(
                    data: Icons.person,
                    controller: nameController,
                    hintText: "Name",
                    isObsecure: false,
                  ),
                  CustomTextField(
                    data: Icons.email,
                    controller: emailController,
                    hintText: "Email",
                    isObsecure: false,
                  ),
                  CustomTextField(
                    data: Icons.lock,
                    controller: passwordController,
                    hintText: "Password",
                    isObsecure: true,
                  ),
                  CustomTextField(
                    data: Icons.lock,
                    controller: confirmPasswordController,
                    hintText: "Confirm Password",
                    isObsecure: true,
                  ),
                  CustomTextField(
                    data: Icons.phone,
                    controller: phoneController,
                    hintText: "Phone",
                    isObsecure: false,
                  ),
                  CustomTextField(
                    data: Icons.location_pin,
                    controller: locationController,
                    hintText: "Store Address",
                    isObsecure: false,
                    enabled: true,
                  ),
                  Container(
                    height: 40,
                    width: 400,
                    alignment: Alignment.center,
                    child: ElevatedButton.icon(
                      label: const Text(
                        "Get My Current Location",
                        style: TextStyle(color: Colors.white),
                      ),
                      icon: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                      ),
                      onPressed: ()
                      {
                      getCurrentLocation();
                      },
                      style: ElevatedButton.styleFrom(
                        primary: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            ElevatedButton(
              child: Text(
                "Sign up",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                primary: Colors.grey,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 10),
              ),
              onPressed: ()
              {
                formValidation(context);
              },
            ),
            const SizedBox(height: 30,)
          ],
        ),
      ),
    );
  }
}
