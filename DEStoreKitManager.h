//
//  DEStoreKitManager.h
//  DEStoreKitManager
//
//  Created by Jeremy Flores on 11/19/12.
//
//  Copyright (c) 2012 Dream Engine Interactive, Inc. ( http://dreamengineinteractive.com )
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


#import <Foundation/Foundation.h>

#import <StoreKit/StoreKit.h>


@interface SKProduct (DEStoreKitManager)

-(NSString *) localizedPrice;

@end






@protocol DEStoreKitManagerDelegate <NSObject>

@optional

-(void) productsFetched: (NSArray *)products
     invalidIdentifiers: (NSArray *)invalidIdentifiers;

-(void) productsFetchFailed: (NSError *)error;


-(void) transactionSucceeded: (SKPaymentTransaction *)transaction;

// If a transaction should be restored but the delegate does not implement transactionRestored:,
// then DEStoreKitManager will call transactionSucceeded: instead. This can be used when a
// restored transaction can be treated identically to a successful transaction.
-(void) transactionRestored: (SKPaymentTransaction *)transaction;

-(void) transactionFailed: (SKPaymentTransaction *)transaction;

// If a transaction was canceled but the delegate does not implement transactionCanceled:,
// then DEStoreKitManager will instead call transactionFailed:.
-(void) transactionCanceled: (SKPaymentTransaction *)transaction;

/*
 Provides a delegate an opportunity to verify the receipt of a completed or restored transaction. If
 this method is not implemented in the delegate, then the transaction will be completed and either
 the delegate's transactionSucceeded: or transactionRestored: will be called. This method must be used
 in conjunction with the Store Kit Manager's transaction:didVerify: method.

 Note that, if this method is implemented in the delegate, the Store Kit Manager will still call
 transactionSucceeded: or transactionRestored: if the receipt was verified. It is therefore recommended
 that your delegate keep the 'unlock feature' code within transactionSucceeded:/transactionRestored:
 and not bundle it with your custom verification procedures to practice separation of concerns.

 If this method is implemented in the delegate, the Store Kit Manager's transaction:didVerify: MUST
 be called to complete the transaction once your delegate has determined the validity of the purchase,
 otherwise transactionSucceeded:/transactionRestored:/transactionFailed: will not be called and the
 transaction will stay in the SKPaymentQueue and never be finalized.
 */
-(void) transactionNeedsVerification:(SKPaymentTransaction *)transaction;

@end



@interface DEStoreKitManager : NSObject

@property (nonatomic, readonly) NSSet *cachedProducts;

+(id)sharedManager;

-(BOOL) canMakePurchases;

// returns nil if product not found
-(SKProduct *)cachedProductWithIdentifier:(NSString *)productIdentifier;

-(void) removeProductsFromCache:(NSSet *)products;
-(void) removeAllProductsFromCache;

// This will cache the products in DEStoreKitManager for later use in memory. If you do not want
// the products to be cached, then use fetchProductsWithIdentifiers:delegate:cacheResult: and pass NO
// for the last parameter.
-(void) fetchProductsWithIdentifiers: (NSSet *)productIdentifiers
                            delegate: (id<DEStoreKitManagerDelegate>) delegate;

-(void) fetchProductsWithIdentifiers: (NSSet *)productIdentifiers
                            delegate: (id<DEStoreKitManagerDelegate>) delegate
                         cacheResult: (BOOL)shouldCache;

#ifdef __BLOCKS__


/*
 Use these if you'd prefer not to use the delegation pattern
 */
-(void) fetchProductsWithIdentifiers: (NSSet *)productIdentifiers
                           onSuccess: (void (^)(NSArray *products, NSArray *invalidIdentifiers))success
                           onFailure: (void (^)(NSError *error))failure;

-(void) fetchProductsWithIdentifiers: (NSSet *)productIdentifiers
                           onSuccess: (void (^)(NSArray *products, NSArray *invalidIdentifiers))success
                           onFailure: (void (^)(NSError *error))failure
                         cacheResult: (BOOL)shouldCache;

#endif


/*
 Attempts to purchase a product with matching productIdentifier.

 This method should only be used if the productIdentifier's SKProduct has already been fetched and
 cached by the StoreKitManager. If your app does not utilize the StoreKitManager's caching system,
 then you should use purchaseProduct:delegate: instead.

 Returns YES if an SKProduct was found in the StoreKitManager's cache matching the provided
 productIdentifier, meaning that the purchase will be attempted. Otherwise, returns NO, indicating
 that there was not a matching SKProduct and therefore no purchase will be attempted.
 */
-(BOOL) purchaseProductWithIdentifier: (NSString *)productIdentifier
                             delegate: (id<DEStoreKitManagerDelegate>) delegate;

-(void) purchaseProduct: (SKProduct *)product
               delegate: (id<DEStoreKitManagerDelegate>) delegate;

#ifdef __BLOCKS__

/*
 Use these if you'd prefer not to use the delegation pattern.
 */
-(BOOL) purchaseProductWithIdentifier: (NSString *)productIdentifier
                            onSuccess: (void (^)(SKPaymentTransaction *transaction))success
                            onRestore: (void (^)(SKPaymentTransaction *transaction))restore
                            onFailure: (void (^)(SKPaymentTransaction *transaction))failure
                             onCancel: (void (^)(SKPaymentTransaction *transaction))cancel
                             onVerify: (void (^)(SKPaymentTransaction *transaction))verify;

-(void) purchaseProduct: (SKProduct *)product
              onSuccess: (void (^)(SKPaymentTransaction *transaction))success
              onRestore: (void (^)(SKPaymentTransaction *transaction))restore
              onFailure: (void (^)(SKPaymentTransaction *transaction))failure
               onCancel: (void (^)(SKPaymentTransaction *transaction))cancel
               onVerify: (void (^)(SKPaymentTransaction *transaction))verify;

#endif


/*
 Notifies the Store Kit Manager that a transaction's receipt has either been verified as valid or
 rejected by Apple's servers as invalid. This method should only be used in conjunction with
 the DEStoreKitManagerDelegate's transactionNeedsVerification: method and called only when the
 delegate's custom verification code has determined the validiy of the transaction.

 Note that, if the delegate does not implement transactionNeedsVerification:, then this method should
 never be called.
 */
-(void) transaction: (SKPaymentTransaction *)transaction
          didVerify: (BOOL)isValid;


@end
