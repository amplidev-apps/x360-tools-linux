import hashlib
import binascii
import struct
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa, padding

class STFSCrypto:
    MODULUS = binascii.unhexlify("b5ff62ebec7bc33ddda0f6e6068e1c841f3f35d530a14ac07758d6844e5888c69602f782cc49bcf778e898a8efa8636e6e3c7aff18b3aafe8efc762a97c5e80063d2615b31baddb45ca7ee6f80da78337dd69d90bddcd156dda13f872176b0b1a74dfa7b9111f5a982ef917468b0555d7d05194fbe3999777782e25c309024cea8f704c702f9f395b81a5eee23927db44e44a956a3d2fd4007ca71a3973ed38d259e9842433cb263fb8a315432cc52886dc586ae484cf919caae81041929f00462dd9259426de93ec426c839613cece5780738b2f9eb6418c10a4616665443ac2f5b2f7f6389a994653062b2d1b42d7eb3bad1dd2f59a83f9212cd8727f129a5")
    P = binascii.unhexlify("eab7176d3520d7d6a99cbb794e38a19c4afc545f7c6c0417769a1bd30de00f099e9181d233063a3d0effa81a07229f277766ffccea1e9d834f2f679bb90185b026530e45845ca86ccd0cf61e2bcaf42da651116a2bbf84ca47df1ea77d392f3bbcecdd182354834903ac6e20db8e4fe7ae7e049b5a0bbae25b0e3fdf191bed7b")
    Q = binascii.unhexlify("c68074fbb5c54b8ef350e17b8efe044c169aecfdcbae23d2fb8926cdb0d25ee7c8fe5e51ac0dee4738d906b6b2034cf139ecc88ee6cbbe4bf8c7d7e93887ccdffd17e6ce29aa2dc04a0d65b0a69b0d9bb4fdabf24704e025facf3a188d2ff1a9bcfd3f19aef2a8c59ea6eaf0b76d00ad5005c7a5b64ff7cf8beb8ded61b34b5f")
    D = binascii.unhexlify("7954ec9d485282293e6b4f44045ebdad6a2a23e375c0dc804f908f02dee5b0846401fa5732dbd34fa5f065c5f51aecf4497da754bb2271ff09fda41c652e9aaaed36eb9221273e783dc5499fab3c502253e4690b293de0e493c0d504c0f9cb211a33fc5260b6a3c6574a60f845cae393a8ae10dfd426664fa501ec3d75b56dddfa7fa594100d357567732bfb843d3a87f31e4550e7d08e390e6f74ac905d99127eb47abeed705bea77cbac57a66eeef5284bd436fa41be31ac7a2baa1a6b13a2d4f71383b844b7611e08484709e49cbd687afce45a19ff70543d48e43d476c8478f60cde60d6fe592c935bc0d47b3df1237a03bd69fea3b3c765ffd1c8c14b33")
    DP = binascii.unhexlify("9c7a0f9e236b3a8f1bbdd250ded06bbd8752e2ea52f2ad64f9bc128cb3eab4b114610136ccaed17e09ffc566af6c6a1a4f99ffddf169be578a1f9a67d0abae756ee20983ad931af3335df96972874d73c4360b9c1d2a5886da94bf1a537b74d27df33e10178dacdb57c8496b3d098a9a745403123c07d1ec3cb42a94bb67f3a7")
    DQ = binascii.unhexlify("8455a352792e325f4ce096525f5402dd646748a9327417e1fd0619de75e1949a85fee98bc8094984d090af2476acddf6269ddb09ef327edd50853a9b7b05333ffe0fef341bc6c92adc08ee75c4675e67cdfe72a184adeac3fc8a26bb08caa11bd3537f6674a1c5d9146f474b24f355c8e003da6e798aa53507f25e9e4122323f")
    IQ = binascii.unhexlify("5bfe79f41929a97f0a961ac4785c830a2b12ddb5050c7f4972a363ca4cbc543d3dd52bbbb4cce815eacb13c91a78c792e0a7e18604d9d5ef3b281bf8f533a9a861c2da820ba5fbf87a8e661c2110a8665861b8dc33d34e155e83ad47b5ff0935a3ede4c441d2338e6e312cfe4cd8fd9e2bd03c4e278f4724a5a5c73792d0d88d")
    PUBLIC_EXPONENT = 3
    @classmethod
    def get_private_key(cls):
        public_numbers = rsa.RSAPublicNumbers(e=cls.PUBLIC_EXPONENT, n=int.from_bytes(cls.MODULUS, "big"))
        return rsa.RSAPrivateNumbers(p=int.from_bytes(cls.P, "big"), q=int.from_bytes(cls.Q, "big"), d=int.from_bytes(cls.D, "big"), dmp1=int.from_bytes(cls.DP, "big"), dmq1=int.from_bytes(cls.DQ, "big"), iqmp=int.from_bytes(cls.IQ, "big"), public_numbers=public_numbers).private_key()
    @staticmethod
    def stock_scramble(data, reverse=False):
        length = len(data)
        if length % 8 != 0: raise ValueError("Data length must be divisible by 8")
        for i in range(0, length // 2, 8):
            j = length - i - 8
            data[i:i+8], data[j:j+8] = data[j:j+8], data[i:i+8]
        if reverse:
            for i in range(0, length, 8): data[i:i+8] = data[i:i+8][::-1]
        return data
    @classmethod
    def sign_stfs_header(cls, header):
        signing_area = header[0x22C : 0x22C + 0x118]
        header_hash = hashlib.sha1(signing_area).digest()
        priv_key = cls.get_private_key()
        signature = priv_key.sign(header_hash, padding.PKCS1v15(), hashes.SHA1())
        return bytearray(signature[::-1])
    @staticmethod
    def calculate_master_hash(hash_block):
        return hashlib.sha1(hash_block).digest()
