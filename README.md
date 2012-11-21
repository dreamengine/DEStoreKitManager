# DEStoreKitManager
[http://github.com/dreamengineinteractive/DEStoreKitManager](http://github.com/dreamengineinteractive/DEStoreKitManager)

## What It Does

`DEStoreKitManager` is an MIT-licensed library that streamlines iOS In-App Purchases. It automatically takes care of the IAP boilerplate for you so you can concentrate on shipping and on making better products.


## Product Fetching

To fetch a list of products, simply have your delegate object adhere to the `DEStoreKitManagerDelegate` protocol and have the following callbacks implemented: `productsFetched:invalidIdentifiers:` and `productsFetchedFailed:`. Then, just call `fetchProductsWithIdentifier:delegate:` and wait for the callbacks to be messaged.

You can have as many simultaneous product fetches going as you'd like (though we recommend doing fewer fetches with more product identifiers in each fetch).

`DEStoreKitManager` automatically caches the products you've received in memory, so you don't need to keep track of the individual `SKProducts`.

If you'd rather not use the automatic product caching and you'd prefer to keep track of the products yourself, then you can use `fetchProductsWithIdentifier:delegate:cacheResult:` and pass `NO` for the last parameter. Then, when the product is to be purchased, simply use `purchaseProduct:delegate:` instead of `purchaseProductWithIdentifier:delegate:`.

### Example

    #import "DEStoreKitManager.h"
    
    @interface MyViewController: UIViewController <DEStoreKitManagerDelegate>
    
    …
    
    @implementation MyViewController

    …

	-(void) viewDidLoad {
		[super viewDidLoad];

		[self fetchProducts];
	}

	// this is a private method for MyViewController to encapsulate the product fetching.
	// This might be useful, for example, if you want to automatically attempt to fetch the products again if it fails.
	-(void) fetchProducts {
		NSSet *productIdentifiers = [NSSet setWithObjects:@"com.example.removeads", @"com.example.upgrade", nil];
	
			[[DEStoreKitManager sharedManager] fetchProductsWithIdentifiers: productIdentifiers
																   delegate: self];	

		// Use fetchProductsWithIdentifiers:delegate:shouldCache instead if you want to specify
		// Whether or not the DEStoreKitManager should cache the products
	}
    
    -(void)productsFetched: (NSArray *)products
     	invalidIdentifiers: (NSArray *)invalidIdentifiers {
     	// If you specified DEStoreKitManager not to cache, then you are responsible for holding onto the products array.
     	// Otherwise, you can record that the products have been fetched here.
    }

	-(void) productsFetchFailed:(NSError *)error {
		// Handle the failure here
	}

    …


## Product Purchasing (Transactions)

To purchase a product, have your delegate implement the following methods: `transactionSucceeded:`, `transactionRestored:` (optional), `transactionFailed:`, and `transactionCanceled:` (optional). Then, use `DEStoreKitManager` to initiate the transaction.

If `transactionRestored:` is not implemented in your delegate, then a restored purchase will be sent instead to `transactionSucceeded:`. Similarly, if `transactionCanceled:` is not implemented, then `transacitonFailed:` will be called instead if the user cancels the purchase.

If you are relying on `DEStoreKitManager` to cache your products, you can call `purchaseProductWithProductIdentifier:delegate:` to start the purchase procedure. If the product has not been fetched and cached into `DEStoreKitManager`, then this will return `NO`, meaning that the purchase will not be attempted. Otherwise, if `DEStoreKitManager` finds an SKProduct with matching product identifier, this method will return `YES`, meaning that a purchase transaction has begun.

If you are keeping track of SKProducts outside of `DEStoreKitManager`, then you should instead use `purchaseProduct:delegate:`, which will immediately begin a purchase transaction.

### Example

    -(IBAction)buyButtonTapped:(id)sender {
    	[[DEStoreKitManager sharedManager] purchaseProductWithProductIdentifier:@"com.example.removeads" delegate:self];	
		[self.activityIndicator startAnimating];
    }

	-(void) transactionSucceeded:(SKPaymentTransaction *)transaction {
		…
		// record the purchase here
		…

		[self.activityIndicator stopAnimating];

		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: @"Purchase Succeeded"
                                                            message: @"Thanks for the purchase!"
                                                           delegate: nil
                                                  cancelButtonTitle: @"OK"
                                                  otherButtonTitles: nil];
        [alertView show];
        [alertView release];
	}

	-(void) transactionFailed:(SKPaymentTransaction *)transaction {
		[self.activityIndicator stopAnimating];

		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle: @"Purchase Failed"
                                                            message: @"Please try again later."
                                                           delegate: nil
                                                  cancelButtonTitle: @"OK"
                                                  otherButtonTitles: nil];
        [alertView show];
        [alertView release];
	}



## Transaction Receipt Verification

`DEStoreKitManager` does not force you to adhere to a specific receipt verification procedure. In fact, though we do recommend receipt validation, `DEStoreKitManager` does not require any validation whatsoever.

Instead, you can optionally choose to verify a receipt by having your delegate implement the `transactionNeedsVerification:` method. Your delegate will then be responsible for determining if the transaction is valid (most likely by communicating with your own server setup which then communicates with Apple's servers).

After the validity has been determined, the delegate is then responsible for notifying the `DEStoreKitManager` by calling `transaction:didVerify:` and letting it know whether or not the receipt was valid.

Once this occurs, `DEStoreKitManager` will then proceed to call either `transactionSucceeded:/transactionRestored:` if the receipt was valid or `transactionFailed:` if the receipt was invalid.