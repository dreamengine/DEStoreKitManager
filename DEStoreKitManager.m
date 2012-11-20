//
//  DEStoreKitManager.m
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


#import "DEStoreKitManager.h"





//**************************************************
//
// Store Kit Manager private methods
//
//**************************************************
#pragma mark - Store Kit Manager private methods

@class DEStoreKitProductsFetchHandler;
@class DEStoreKitTransactionHandler;
@interface DEStoreKitManager ()

@property (nonatomic, retain) NSMutableSet *productsFetchHandlers;
@property (nonatomic, retain) NSMutableSet *transactionHandlers;

-(void) addProductsToCache:(NSSet *)products;

-(void) productsFetchHandlerDidFinish:(DEStoreKitProductsFetchHandler *)handler;

-(void) transactionHandlerDidFinish:(DEStoreKitTransactionHandler *)handler;

@end










//**************************************************
//
// Products Fetch Handler
//
//**************************************************
#pragma mark - Products Fetch Handler

@interface DEStoreKitProductsFetchHandler : NSObject <SKProductsRequestDelegate>

@property (nonatomic) BOOL shouldCache;
@property (nonatomic, retain) NSSet *productIdentifiers;
@property (nonatomic, assign) DEStoreKitManager *storeKitManager;
@property (nonatomic, assign) id<DEStoreKitManagerDelegate> delegate;

@property (nonatomic, retain) SKProductsRequest *request;

-(void) fetch;

@end


@implementation DEStoreKitProductsFetchHandler

@synthesize shouldCache = shouldCache_;
@synthesize productIdentifiers = productIdentifiers_;
@synthesize storeKitManager = storeKitManager_;
@synthesize delegate = delegate_;

@synthesize request = request_;

-(void) dealloc {
    self.productIdentifiers = nil;
    self.storeKitManager = nil;
    self.delegate = nil;
    self.request.delegate = nil;
    self.request = nil;

    [super dealloc];
}

-(void) fetch {
    self.request = [[[SKProductsRequest alloc] initWithProductIdentifiers:self.productIdentifiers] autorelease];
    self.request.delegate = self;
    [self.request start];
}

- (void)productsRequest: (SKProductsRequest *)request
     didReceiveResponse: (SKProductsResponse *)response {
    NSSet *fetchedProducts = [NSSet setWithArray:response.products];
    if (self.shouldCache) {
        [self.storeKitManager addProductsToCache:fetchedProducts];
    }

    if (self.delegate && [self.delegate respondsToSelector:@selector(productsFetched:invalidIdentifiers:)]) {
        [self.delegate productsFetched: response.products
                    invalidIdentifiers: response.invalidProductIdentifiers];
    }

    self.request.delegate = nil;
    [self.storeKitManager productsFetchHandlerDidFinish:self];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    if (self.delegate && [self.delegate respondsToSelector:@selector(productsFetchFailed:)]) {
        [self.delegate productsFetchFailed:error];
    }

    self.request.delegate = nil;
    [self.storeKitManager productsFetchHandlerDidFinish:self];
}

@end










//**************************************************
//
// Transaction Handler
//
//**************************************************
#pragma mark - Transaction Handler

@interface DEStoreKitTransactionHandler : NSObject <SKPaymentTransactionObserver>

@property (nonatomic, retain) SKProduct *product;
@property (nonatomic, assign) DEStoreKitManager *storeKitManager;
@property (nonatomic, assign) id<DEStoreKitManagerDelegate> delegate;

@property (nonatomic, retain) SKPayment *payment;

-(void) purchase;

-(void) transaction:(SKPaymentTransaction *)transaction
        wasVerified:(BOOL)isValid;

@end

@interface DEStoreKitTransactionHandler ()

-(void) finishTransaction: (SKPaymentTransaction *)transaction
            wasSuccessful: (BOOL)wasSuccessful;

@end


@implementation DEStoreKitTransactionHandler

@synthesize product = product_;
@synthesize storeKitManager = storeKitManager_;
@synthesize delegate = delegate_;

@synthesize payment = payment_;

-(void) dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];

    self.product = nil;
    self.storeKitManager = nil;
    self.delegate = nil;
    self.payment = nil;
    
    [super dealloc];
}

-(void) purchase {
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];

    self.payment = [SKPayment paymentWithProduct:self.product];

    [[SKPaymentQueue defaultQueue] addPayment:self.payment];
}

- (void)paymentQueue: (SKPaymentQueue *)queue
 updatedTransactions: (NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        if ([transaction.payment isEqual:self.payment]) {
            switch (transaction.transactionState) {
                case SKPaymentTransactionStatePurchased:
                case SKPaymentTransactionStateRestored:
                    if (self.delegate && [self.delegate respondsToSelector:@selector(transactionNeedsVerification:)]) {
                        [self.delegate transactionNeedsVerification:transaction];
                    }
                    else {
                        [self finishTransaction:transaction wasSuccessful:YES];
                    }
                    break;
                case SKPaymentTransactionStateFailed:
                    [self finishTransaction:transaction wasSuccessful:NO];
                    break;
                case SKPaymentTransactionStatePurchasing:
                default:
                    break;
            }
            break;
        }
    }
}

-(void) transaction: (SKPaymentTransaction *)transaction
        wasVerified: (BOOL)isValid {
    [self finishTransaction:transaction wasSuccessful:isValid];
}

-(void) finishTransaction: (SKPaymentTransaction *)transaction
            wasSuccessful: (BOOL)wasSuccessful {
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];

    if (self.delegate) {
        if (wasSuccessful) {
            if (transaction.transactionState == SKPaymentTransactionStateRestored &&
                [self.delegate respondsToSelector:@selector(transactionRestored:)]) {
                [self.delegate transactionRestored:transaction];
            }
            else if ([self.delegate respondsToSelector:@selector(transactionSucceeded:)]) {
                [self.delegate transactionSucceeded:transaction];
            }
        }
        else {
            if (transaction.error.code == SKErrorPaymentCancelled &&
                [self.delegate respondsToSelector:@selector(transactionCanceled:)]) {
                [self.delegate transactionCanceled:transaction];
            }
            else if ([self.delegate respondsToSelector:@selector(transactionFailed:)]) {
                [self.delegate transactionFailed:transaction];
            }
        }
    }

    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    [self.storeKitManager transactionHandlerDidFinish:self];
}


@end










//**************************************************
//
// Store Kit Manager
//
//**************************************************
#pragma mark - Store Kit Manager


@implementation DEStoreKitManager

@synthesize cachedProducts = cachedProducts_;
@synthesize productsFetchHandlers = productsFetchHandlers_;
@synthesize transactionHandlers = transactionHandlers_;


#pragma mark - Dealloc

-(void) dealloc {
    [cachedProducts_ release], cachedProducts_ = nil;
    self.productsFetchHandlers = nil;
    self.transactionHandlers = nil;

    [super dealloc];
}


#pragma mark - Static method

+(id)sharedManager {
    static DEStoreKitManager *sharedManager = nil;

    if (!sharedManager) {
        sharedManager = [DEStoreKitManager new];
    }

    return sharedManager;
}


#pragma mark - Initialization

-(id) init {
    if (self=[super init]) {
        cachedProducts_ = [NSSet new];

        self.productsFetchHandlers = [NSMutableSet set];
        self.transactionHandlers = [NSMutableSet set];
    }

    return self;
}


#pragma mark - Can Make Purchases

- (BOOL)canMakePurchases {
    return [SKPaymentQueue canMakePayments];
}


#pragma mark - Cache

-(void) addProductsToCache:(NSSet *)products {
    NSSet *newCache = [self.cachedProducts setByAddingObjectsFromSet:products];
    [cachedProducts_ release];
    cachedProducts_ = [newCache retain];
}

-(void) removeProductsFromCache:(NSSet *)products {
    NSMutableSet *mutableCache = [NSMutableSet setWithSet:cachedProducts_];
    for (id product in products) {
        [mutableCache removeObject:product];
    }

    NSSet *newCache = [NSSet setWithSet:mutableCache];
    [cachedProducts_ release];
    cachedProducts_ = [newCache retain];
}

-(void) removeAllProductsFromCache {
    NSSet *newCache = [NSSet set];
    [cachedProducts_ release];
    cachedProducts_ = [newCache retain];
}


#pragma mark - Handlers

-(void) productsFetchHandlerDidFinish:(DEStoreKitProductsFetchHandler *)handler {
    [self.productsFetchHandlers removeObject:handler];  // this should decrease the retain count to 0 for the handler, thereby deallocing it
}

-(void) transactionHandlerDidFinish:(DEStoreKitTransactionHandler *)handler {
    [self.transactionHandlers removeObject:handler];
}


#pragma mark - Fetch Products

-(void) fetchProductsWithIdentifiers: (NSSet *)productIdentifiers
                            delegate: (id<DEStoreKitManagerDelegate>) delegate {
    [self fetchProductsWithIdentifiers: productIdentifiers
                              delegate: delegate
                           cacheResult: YES];
}

-(void) fetchProductsWithIdentifiers: (NSSet *)productIdentifiers
                            delegate: (id<DEStoreKitManagerDelegate>) delegate
                         cacheResult: (BOOL)shouldCache {
    DEStoreKitProductsFetchHandler *handler = [[DEStoreKitProductsFetchHandler new] autorelease];
    handler.storeKitManager = self;
    handler.shouldCache = shouldCache;
    handler.productIdentifiers = productIdentifiers;
    handler.delegate = delegate;
    
    [self.productsFetchHandlers addObject:handler];

    [handler fetch];
}


#pragma mark - Transaction

-(BOOL) purchaseProductWithIdentifier: (NSString *)productIdentifier
                             delegate: (id<DEStoreKitManagerDelegate>) delegate {
    for (SKProduct *product in self.cachedProducts) {
        if ([product.productIdentifier isEqualToString:productIdentifier]) {
            [self purchaseProduct: product
                         delegate: delegate];
            return YES;
            break;
        }
    }

    return NO;
}

-(void) purchaseProduct: (SKProduct *)product
               delegate: (id<DEStoreKitManagerDelegate>) delegate {
    DEStoreKitTransactionHandler *handler = [[DEStoreKitTransactionHandler new] autorelease];

    handler.storeKitManager = self;
    handler.product = product;
    handler.delegate = delegate;

    [self.transactionHandlers addObject:handler];

    [handler purchase];
}

-(void) transaction: (SKPaymentTransaction *)transaction
          didVerify: (BOOL)isValid {
    for (DEStoreKitTransactionHandler *handler in self.transactionHandlers) {
        if ([handler.payment isEqual:transaction.payment]) {
            [handler transaction: transaction
                     wasVerified: isValid];
            break;
        }
    }
}

@end
